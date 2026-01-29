package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/trace"
)

// Config contiene la configuración del servicio
type Config struct {
	Port            string
	OrderServiceURL string
	OTLPEndpoint    string
	ServiceName     string
}

// App contiene las dependencias de la aplicación
type App struct {
	config      Config
	httpClient  *http.Client
	tracer      trace.Tracer
	meter       metric.Meter
	reqCounter  metric.Int64Counter
	reqDuration metric.Float64Histogram
	logger      *slog.Logger
}

// OrderRequest representa una solicitud de pedido
type OrderRequest struct {
	UserID    string  `json:"user_id"`
	ProductID string  `json:"product_id"`
	Quantity  int     `json:"quantity"`
	Amount    float64 `json:"amount"`
}

// OrderResponse representa la respuesta de un pedido
type OrderResponse struct {
	OrderID string  `json:"order_id"`
	Status  string  `json:"status"`
	Amount  float64 `json:"amount"`
	Message string  `json:"message,omitempty"`
	TraceID string  `json:"trace_id,omitempty"`
}

func main() {
	config := Config{
		Port:            getEnv("PORT", "8080"),
		OrderServiceURL: getEnv("ORDER_SERVICE_URL", "http://order-service:8081"),
		OTLPEndpoint:    getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", "otel-collector:4317"),
		ServiceName:     getEnv("OTEL_SERVICE_NAME", "api-gateway"),
	}

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	ctx := context.Background()
	shutdown, err := setupOTelSDK(ctx, config.ServiceName, config.OTLPEndpoint)
	if err != nil {
		logger.Error("Failed to setup OpenTelemetry", "error", err)
		os.Exit(1)
	}
	defer func() {
		if err := shutdown(ctx); err != nil {
			logger.Error("Failed to shutdown OpenTelemetry", "error", err)
		}
	}()

	app, err := NewApp(config, logger)
	if err != nil {
		logger.Error("Failed to create app", "error", err)
		os.Exit(1)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", app.healthHandler)
	mux.HandleFunc("/api/v1/orders", app.createOrderHandler)
	mux.HandleFunc("/api/v1/orders/", app.getOrderHandler)

	handler := otelhttp.NewHandler(mux, "api-gateway",
		otelhttp.WithMessageEvents(otelhttp.ReadEvents, otelhttp.WriteEvents),
	)

	server := &http.Server{
		Addr:         ":" + config.Port,
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		logger.Info("Starting API Gateway", "port", config.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("Server error", "error", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Error("Server forced to shutdown", "error", err)
	}
	logger.Info("Server stopped")
}

func NewApp(config Config, logger *slog.Logger) (*App, error) {
	httpClient := &http.Client{
		Transport: otelhttp.NewTransport(http.DefaultTransport),
		Timeout:   30 * time.Second,
	}

	tracer := otel.Tracer(config.ServiceName)
	meter := otel.Meter(config.ServiceName)

	reqCounter, err := meter.Int64Counter("api_gateway_requests_total",
		metric.WithDescription("Total number of requests to the API Gateway"),
		metric.WithUnit("{request}"),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create request counter: %w", err)
	}

	reqDuration, err := meter.Float64Histogram("api_gateway_request_duration_seconds",
		metric.WithDescription("Duration of requests to the API Gateway"),
		metric.WithUnit("s"),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create duration histogram: %w", err)
	}

	return &App{
		config:      config,
		httpClient:  httpClient,
		tracer:      tracer,
		meter:       meter,
		reqCounter:  reqCounter,
		reqDuration: reqDuration,
		logger:      logger,
	}, nil
}

func (a *App) healthHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	span := trace.SpanFromContext(ctx)
	span.SetAttributes(attribute.String("health.status", "ok"))

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "healthy",
		"service": a.config.ServiceName,
	})
}

func (a *App) createOrderHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	startTime := time.Now()

	span := trace.SpanFromContext(ctx)
	span.SetAttributes(
		attribute.String("http.method", r.Method),
		attribute.String("http.url", r.URL.String()),
	)

	traceID := span.SpanContext().TraceID().String()

	logger := a.logger.With(
		"trace_id", traceID,
		"span_id", span.SpanContext().SpanID().String(),
	)

	if r.Method != http.MethodPost {
		a.recordMetrics(ctx, startTime, "create_order", http.StatusMethodNotAllowed)
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var orderReq OrderRequest
	if err := json.NewDecoder(r.Body).Decode(&orderReq); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "Invalid request body")
		a.recordMetrics(ctx, startTime, "create_order", http.StatusBadRequest)

		logger.Error("Failed to decode request", "error", err)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	span.SetAttributes(
		attribute.String("order.user_id", orderReq.UserID),
		attribute.String("order.product_id", orderReq.ProductID),
		attribute.Int("order.quantity", orderReq.Quantity),
		attribute.Float64("order.amount", orderReq.Amount),
	)

	logger.Info("Processing order request",
		"user_id", orderReq.UserID,
		"product_id", orderReq.ProductID,
		"quantity", orderReq.Quantity,
	)

	ctx, childSpan := a.tracer.Start(ctx, "call-order-service",
		trace.WithSpanKind(trace.SpanKindClient),
	)
	defer childSpan.End()

	orderResp, err := a.callOrderService(ctx, orderReq)
	if err != nil {
		childSpan.RecordError(err)
		childSpan.SetStatus(codes.Error, err.Error())
		span.SetStatus(codes.Error, "Failed to create order")
		a.recordMetrics(ctx, startTime, "create_order", http.StatusInternalServerError)

		logger.Error("Failed to call order service", "error", err)
		http.Error(w, "Failed to create order", http.StatusInternalServerError)
		return
	}

	orderResp.TraceID = traceID

	span.SetStatus(codes.Ok, "Order created successfully")
	a.recordMetrics(ctx, startTime, "create_order", http.StatusCreated)

	logger.Info("Order created successfully",
		"order_id", orderResp.OrderID,
		"status", orderResp.Status,
	)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(orderResp)
}

func (a *App) getOrderHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	startTime := time.Now()
	span := trace.SpanFromContext(ctx)

	orderID := r.URL.Path[len("/api/v1/orders/"):]
	span.SetAttributes(attribute.String("order.id", orderID))

	a.recordMetrics(ctx, startTime, "get_order", http.StatusOK)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(OrderResponse{
		OrderID: orderID,
		Status:  "completed",
		Amount:  99.99,
	})
}

func (a *App) callOrderService(ctx context.Context, order OrderRequest) (*OrderResponse, error) {
	ctx, serSpan := a.tracer.Start(ctx, "serialize-order-request")
	body, err := json.Marshal(order)
	serSpan.End()
	if err != nil {
		return nil, fmt.Errorf("failed to marshal order: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		a.config.OrderServiceURL+"/orders",
		io.NopCloser(io.NewSectionReader(
			readerAt(body), 0, int64(len(body)),
		)),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := a.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to call order service: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("order service error: %s", string(body))
	}

	var orderResp OrderResponse
	if err := json.NewDecoder(resp.Body).Decode(&orderResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &orderResp, nil
}

func (a *App) recordMetrics(ctx context.Context, startTime time.Time, endpoint string, statusCode int) {
	duration := time.Since(startTime).Seconds()

	attrs := []attribute.KeyValue{
		attribute.String("endpoint", endpoint),
		attribute.Int("status_code", statusCode),
	}

	a.reqCounter.Add(ctx, 1, metric.WithAttributes(attrs...))
	a.reqDuration.Record(ctx, duration, metric.WithAttributes(attrs...))
}

type readerAt []byte

func (r readerAt) ReadAt(p []byte, off int64) (n int, err error) {
	if off >= int64(len(r)) {
		return 0, io.EOF
	}
	n = copy(p, r[off:])
	return n, nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
