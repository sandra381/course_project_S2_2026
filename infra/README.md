# Infraestructura — Workspace de IaC
 
Este directorio contiene todo el código Terraform del proyecto. 

---
 
## Requisitos previos
 
- [Terraform](https://developer.hashicorp.com/terraform/downloads) `~> 1.8`
- Credenciales de AWS configuradas (ver sección de credenciales)
- Git
---
 
## 1. Configuración de credenciales
 
Las credenciales nunca se almacenan en el código ni en archivos versionados. Se deben proveer como variables de entorno antes de ejecutar cualquier comando de Terraform:
 
```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="tu-secret-key"
export AWS_REGION="us-east-1"
```
 
> En CI (GitHub Actions), estas credenciales se almacenan como secrets cifrados del repositorio y se inyectan automáticamente en el runner. Ver `.github/workflows/terraform-ci.yml`.
 
---
 
## 2. Inicialización del workspace
 
```bash
cd infra/
 
# Descargar plugins del provider
terraform init
 
# Verificar el formato del código
terraform fmt -recursive
 
# Validar la configuración (sin llamadas a AWS)
terraform validate
```
 
---
 
## 3. Ejecutar plan y apply localmente
 
```bash
# Generar el plan de ejecución usando variables de dev
terraform plan -var-file=envs/dev/dev.tfvars -out=tfplan
 
# Revisar el plan y luego aplicar
terraform apply tfplan
```
 
Para apuntar a producción:
 
```bash
terraform plan -var-file=envs/prod/prod.tfvars -out=tfplan
terraform apply tfplan
```
 
Para destruir recursos (usar con precaución):
 
```bash
terraform destroy -var-file=envs/dev/dev.tfvars
```
 
---
 
## Estructura del repositorio
 
```
course_project_S2_2026/
├── .github/workflows/terraform-ci.yml  # Pipeline de CI que valida y planifica en cada PR
├── infra/
│   ├── provider.tf                     # Configuración del proveedor AWS y versiones
│   ├── variables.tf                    # Variables de entrada del workspace
│   ├── outputs.tf                      # Valores de salida expuestos tras el apply
│   ├── main.tf                         # Recursos de infraestructura
│   ├── envs/dev/dev.tfvars             # Variables del ambiente de desarrollo
│   ├── envs/prod/prod.tfvars           # Variables del ambiente de producción
│   ├── docs/delivery-1-summary.md      # Resumen escrito del Delivery 1
│   └── README.md                       # Documentación y guía de uso del workspace
```
---
 
## Notas importantes
 
- **Estado local**: Los Deliveries 1 al 3 usan estado local (`terraform.tfstate`). La migración a estado remoto se realiza en el Delivery 2.
- **Sin recursos manuales**: Toda la infraestructura debe crearse a través de este código. Nada se crea desde la consola de AWS.
- **Idempotencia**: Ejecutar `terraform apply` dos veces seguidas no debe producir cambios en la segunda ejecución.