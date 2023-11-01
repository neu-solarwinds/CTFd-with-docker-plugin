# NEU Team Solarwinds CTFd project

- [NEU Team Solarwinds CTFd project](#neu-team-solarwinds-ctfd-project)
  - [Terraform Setup](#terraform-setup)
    - [Google Cloud Shell](#google-cloud-shell)
  - [Credits](#credits)

## Terraform Setup

### Google Cloud Shell

```bash
git clone https://github.com/neu-solarwinds/CTFd-with-docker-plugin.git ## if private then need to use ssh and ssh keys
cd CTFd-with-docker-plugin
terraform init
terraform plan
terraform apply -auto-approve
```

![architecture](architecture.drawio.png)

## Credits

<https://github.com/CTFd/CTFd>

<https://github.com/phannhat17/CTFd-Docker-Plugin>
