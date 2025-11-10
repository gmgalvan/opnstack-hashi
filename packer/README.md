### 1. Inicializar Packer
```bash
packer init .
```

### 2. Validar configuración
```bash
packer validate .
```

### 3. Build 
```bash
packer build \
  -var "aws_account_id=$AWS_ACCOUNT_ID" \
  dockerfile-to-ecr.pkr.hcl
```

### 4. Build con variables de desarrollo
```bash
packer build -var-file=environments/dev.pkrvars.hcl .
```

