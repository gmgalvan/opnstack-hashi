package main

import (
	"context"
	"errors"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	"go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

// setupOTelSDK configura el SDK de OpenTelemetry y retorna una función de shutdown
func setupOTelSDK(ctx context.Context, serviceName, otlpEndpoint string) (func(context.Context) error, error) {
	var shutdownFuncs []func(context.Context) error

	// Función de shutdown que ejecuta todas las funciones de limpieza
	shutdown := func(ctx context.Context) error {
		var err error
		for _, fn := range shutdownFuncs {
			err = errors.Join(err, fn(ctx))
		}
		return err
	}

	// Manejar errores llamando shutdown si algo falla
	handleErr := func(inErr error) error {
		return errors.Join(inErr, shutdown(ctx))
	}

	// Crear recurso que identifica el servicio
	res, err := resource.Merge(
		resource.Default(),
		resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceName(serviceName),
			semconv.ServiceVersion("1.0.0"),
			attribute.String("environment", getEnv("ENVIRONMENT", "development")),
			attribute.String("deployment.region", getEnv("REGION", "local")),
		),
	)
	if err != nil {
		return nil, handleErr(err)
	}

	// Configurar propagación de contexto
	// W3C Trace Context es el estándar recomendado
	prop := propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{}, // W3C Trace Context
		propagation.Baggage{},      // W3C Baggage
	)
	otel.SetTextMapPropagator(prop)

	// Configurar Trace Provider
	traceProvider, err := newTraceProvider(ctx, res, otlpEndpoint)
	if err != nil {
		return nil, handleErr(err)
	}
	shutdownFuncs = append(shutdownFuncs, traceProvider.Shutdown)
	otel.SetTracerProvider(traceProvider)

	// Configurar Meter Provider
	meterProvider, err := newMeterProvider(ctx, res, otlpEndpoint)
	if err != nil {
		return nil, handleErr(err)
	}
	shutdownFuncs = append(shutdownFuncs, meterProvider.Shutdown)
	otel.SetMeterProvider(meterProvider)

	return shutdown, nil
}

// newTraceProvider crea un TracerProvider configurado para OTLP
func newTraceProvider(ctx context.Context, res *resource.Resource, endpoint string) (*trace.TracerProvider, error) {
	// Crear exporter OTLP sobre gRPC
	traceExporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(endpoint),
		otlptracegrpc.WithInsecure(), // En producción, usar WithTLSCredentials
		otlptracegrpc.WithTimeout(5*time.Second),
	)
	if err != nil {
		return nil, err
	}

	// Configurar el TracerProvider
	// En producción, considerar:
	// - Sampling basado en ratio (ej: 10%)
	// - Límites de atributos y eventos
	traceProvider := trace.NewTracerProvider(
		trace.WithResource(res),
		// BatchSpanProcessor agrupa spans antes de exportar (mejor rendimiento)
		trace.WithBatcher(traceExporter,
			trace.WithBatchTimeout(5*time.Second),
			trace.WithMaxQueueSize(2048),
			trace.WithMaxExportBatchSize(512),
		),
		// Sampler: En desarrollo usar AlwaysSample, en producción usar ratio
		// trace.WithSampler(trace.TraceIDRatioBased(0.1)), // 10% en producción
		trace.WithSampler(trace.AlwaysSample()), // 100% para desarrollo/demo
	)

	return traceProvider, nil
}

// newMeterProvider crea un MeterProvider configurado para OTLP
func newMeterProvider(ctx context.Context, res *resource.Resource, endpoint string) (*metric.MeterProvider, error) {
	// Crear exporter OTLP para métricas
	metricExporter, err := otlpmetricgrpc.New(ctx,
		otlpmetricgrpc.WithEndpoint(endpoint),
		otlpmetricgrpc.WithInsecure(),
		otlpmetricgrpc.WithTimeout(5*time.Second),
	)
	if err != nil {
		return nil, err
	}

	// Configurar el MeterProvider
	meterProvider := metric.NewMeterProvider(
		metric.WithResource(res),
		// PeriodicReader exporta métricas cada intervalo
		metric.WithReader(metric.NewPeriodicReader(metricExporter,
			metric.WithInterval(15*time.Second), // Ajustar según necesidad
		)),
	)

	return meterProvider, nil
}
