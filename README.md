<div>

# Escenario 3: Ejercicio Práctico Completo con CI/CD y Seguridad 🚀 (AWS)

</div>

<div class="page-body">

## Repositorio

Para este escenario se creó el repositorio público en GitHub:

<https://github.com/zimlama/aristos-escenario3>

Este contiene el código de la aplicación, los archivos de infraestructura como código (Terraform) y los workflows de CI/CD.

------------------------------------------------------------------------

## Tarea 1: Despliegue con CI/CD y AWS ECS

En lugar de **Cloud Build y Cloud Run** (GCP), se utilizó la nube de **AWS** con el siguiente flujo:

1.  **Secrets en GitHub Actions**:

    Se configuraron variables seguras para la autenticación y despliegue:

    - `AWS_ACCESS_KEY_ID`
      <figure id="28191892-6feb-809a-8ad4-cc060551869c" class="image">
      <a href="Escenario%203%20Ejercicio%20Pr%C3%A1ctico%20Completo%20con%20CI%20CD%20%20281918926feb80fba0d4cad3ba31de8a/AWS_ACCESS_KEY_ID.png"><img src="./assets/Escenario 3 Ejercicio Práctico Completo con CI CD  281918926feb80fba0d4cad3ba31de8a/AWS_ACCESS_KEY_ID.png" style="width:2560px" /></a>
      </figure>

    <!-- -->

    - `AWS_SECRET_ACCESS_KEY`
      <figure id="28191892-6feb-8091-8b3f-dbfe5a8fdbef">
      <div class="source">
      <a href="https://www.notion.soundefined"></a>
      </div>
      </figure>

    <!-- -->

    - `ECR_REPOSITORY`
      <figure id="28191892-6feb-8034-b928-ffe70d9af729" class="image">
      <a href="Escenario%203%20Ejercicio%20Pr%C3%A1ctico%20Completo%20con%20CI%20CD%20%20281918926feb80fba0d4cad3ba31de8a/ECR_REPOSITORY.png"><img src="./assets/Escenario 3 Ejercicio Práctico Completo con CI CD  281918926feb80fba0d4cad3ba31de8a/ECR_REPOSITORY.png" style="width:2560px" /></a>
      </figure>

    <!-- -->

    - `ECS_SERVICE_NAME`
      <figure id="28191892-6feb-80eb-b611-d7716e1efef9" class="image">
      <a href="Escenario%203%20Ejercicio%20Pr%C3%A1ctico%20Completo%20con%20CI%20CD%20%20281918926feb80fba0d4cad3ba31de8a/ECS_CLUSTER_NAME.png"><img src="./assets/Escenario 3 Ejercicio Práctico Completo con CI CD  281918926feb80fba0d4cad3ba31de8a/ECS_CLUSTER_NAME.png" style="width:2560px" /></a>
      </figure>

    <!-- -->

    - `ECS_CLUSTER_NAME`
      <figure id="28191892-6feb-8022-892d-c87d6e8dc3bf" class="image">
      <a href="Escenario%203%20Ejercicio%20Pr%C3%A1ctico%20Completo%20con%20CI%20CD%20%20281918926feb80fba0d4cad3ba31de8a/ECS_SERVICE_NAME.png"><img src="./assets/Escenario 3 Ejercicio Práctico Completo con CI CD  281918926feb80fba0d4cad3ba31de8a/ECS_SERVICE_NAME.png" style="width:2560px" /></a>
      </figure>

<!-- -->

2.  **Infraestructura con Terraform**:

    Se definieron recursos en Terraform para la creación del cluster de ECS, servicios y balanceador de carga con certificado SSL de ACM:

    ``` code
    variable "certificate_arn" {
      type        = string
      description = "ACM certificate ARN for your domain (same region as ALB)."
      default     = "arn:aws:acm:us-east-1:064625181580:certificate/ccf638af-6cc7-4f25-9362-a0e5e93bda44"
    }
    ```

<!-- -->

3.  **Pipeline de despliegue (CI/CD)**:

    - **Build de imagen Docker multi-plataforma** forzada a `linux/amd64`.

    <!-- -->

    - **Push automático a ECR** (Elastic Container Registry).

    <!-- -->

    - **Actualización del servicio en ECS** con *rolling update* forzado para desplegar la nueva versión.

    Ejemplo de comandos ejecutados:

    ``` code
    aws ecr get-login-password --region "$AWS_REGION" --profile "$AWS_PROFILE" \
    | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

    docker buildx build --platform linux/amd64 \
      -t "${IMAGE_URI}:latest" \
      --push .

    aws ecs update-service \
      --cluster aws-ci-cd-sec-app-cluster \
      --service aws-ci-cd-sec-app-svc \
      --force-new-deployment \
      --region "$AWS_REGION" \
      --profile "$AWS_PROFILE"
    ```

------------------------------------------------------------------------

## Tarea 2: Gestión de Seguridad en AWS

Se aplicaron buenas prácticas de seguridad equivalentes a las solicitadas en GCP:

1.  **IAM**:
    - Creación de roles con privilegios mínimos para los servicios de ECS y el pipeline de CI/CD.

    <!-- -->

    - Uso de **IAM Roles for Service Accounts (IRSA)** para evitar credenciales estáticas.

<!-- -->

2.  **Red y Firewall (equivalente a Cloud Armor)**:
    - Se definieron **Security Groups** y **NACLs** para restringir el tráfico entrante.
      <figure id="28191892-6feb-80d1-9195-d6b32355d8f4" class="image">
      <a href="Escenario%203%20Ejercicio%20Pr%C3%A1ctico%20Completo%20con%20CI%20CD%20%20281918926feb80fba0d4cad3ba31de8a/WhatsApp_Image_2025-10-03_at_1.22.20_PM-2.jpeg"><img src="./assets/Escenario 3 Ejercicio Práctico Completo con CI CD  281918926feb80fba0d4cad3ba31de8a/WhatsApp_Image_2025-10-03_at_1.22.20_PM-2.jpeg" style="width:331.97918701171875px" /></a>
      </figure>

    <!-- -->

    - Se configuró una regla que bloquea tráfico proveniente de direcciones IP específicas (ejemplo: `191.95.37.141/32`).
      <figure id="28191892-6feb-801a-8a62-e5d9cae22361" class="image">
      <a href="Escenario%203%20Ejercicio%20Pr%C3%A1ctico%20Completo%20con%20CI%20CD%20%20281918926feb80fba0d4cad3ba31de8a/WhatsApp_Image_2025-10-03_at_1.22.20_PM.jpeg"><img src="./assets/Escenario 3 Ejercicio Práctico Completo con CI CD  281918926feb80fba0d4cad3ba31de8a/WhatsApp_Image_2025-10-03_at_1.22.20_PM.jpeg" style="width:654.0104370117188px" /></a>
      </figure>

      <figure id="28191892-6feb-8032-91ab-de2a0f930a43" class="image">
      <a href="Escenario%203%20Ejercicio%20Pr%C3%A1ctico%20Completo%20con%20CI%20CD%20%20281918926feb80fba0d4cad3ba31de8a/WhatsApp_Image_2025-10-03_at_1.23.29_PM.jpeg"><img src="./assets/Escenario 3 Ejercicio Práctico Completo con CI CD  281918926feb80fba0d4cad3ba31de8a/WhatsApp_Image_2025-10-03_at_1.23.29_PM.jpeg" style="width:654.0104370117188px" /></a>
      </figure>

<!-- -->

3.  **Cifrado y HTTPS obligatorio**:
    - Integración de certificado SSL/TLS en AWS ACM.

    <!-- -->

    - Configuración del ALB (Application Load Balancer) para aceptar únicamente tráfico HTTPS.

------------------------------------------------------------------------

## Verificación

- Se desplegó la aplicación y se accedió a través de la URL pública generada por el Load Balancer de ECS, confirmando que el pipeline funciona tras cada push en `main`.

<!-- -->

- Desde la IP bloqueada se verificó que el servicio rechaza el acceso, validando que las políticas de seguridad funcionan.

<!-- -->

- Logs en CloudWatch confirmaron la aplicación de las reglas.

------------------------------------------------------------------------

## Entregables

- **Repositorio GitHub**: [aristos-escenario3](https://github.com/zimlama/aristos-escenario3)

<!-- -->

- **Aplicación desplegada** en ECS con ALB y HTTPS habilitado.
  - [https://aws-ci-cd-sec-app-alb-1639738126.us-east-1.elb.amazonaws.com](https://aws-ci-cd-sec-app-alb-1639738126.us-east-1.elb.amazonaws.com/)

<!-- -->

- **Terraform files** (`main.tf`, `variables.tf`, `outputs.tf`) con definición de la infraestructura.

<!-- -->

- **Workflows CI/CD** en GitHub Actions (`cicd.yml`).

<!-- -->

- **Pruebas de seguridad** documentadas mostrando acceso denegado desde IP bloqueada.

------------------------------------------------------------------------

</div>

<span class="sans" style="font-size:14px;padding-top:2em"></span>
