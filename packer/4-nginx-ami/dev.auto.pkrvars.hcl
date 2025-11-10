aws_region    = "us-east-1"
instance_type = "t3.micro"

# Visible (no sensible)
html_title   = "¡Hola Mundo desde Nginx!"
html_message = "AMI creada con HashiCorp Packer + Nginx 🚀"

# Ejemplo de variable sensible (no la uses a menos que haga falta)
# Se declarÓ como "sensitive = true" en el template.
secret_banner = "token-super-secreto"
