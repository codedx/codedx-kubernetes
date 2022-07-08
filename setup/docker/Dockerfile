FROM alpine:3.15.4

# Install curl, git, jre, openssl
RUN  apk update && \
	apk add --no-cache curl git openjdk8-jre openssl

# Install helm
RUN  mkdir -p /opt/helm && \
	curl -L https://get.helm.sh/helm-v3.8.1-linux-amd64.tar.gz -o /tmp/helm-v3.8.1-linux-amd64.tar.gz && \
	tar zxf /tmp/helm-v3.8.1-linux-amd64.tar.gz -C /opt/helm && \
	rm /tmp/helm-v3.8.1-linux-amd64.tar.gz && \
	ln -s /opt/helm/linux-amd64/helm /usr/bin/helm && \
	helm version

# Install kubeseal
RUN  curl -L https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.17.4/kubeseal-0.17.4-linux-amd64.tar.gz -o /tmp/kubeseal-0.17.4-linux-amd64.tar.gz && \
	mkdir -p /opt/kubeseal && \
	tar zxf /tmp/kubeseal-0.17.4-linux-amd64.tar.gz -C /opt/kubeseal && \
	rm /tmp/kubeseal-0.17.4-linux-amd64.tar.gz && \
	ln -s /opt/kubeseal/kubeseal /usr/bin/kubeseal

# Install pwsh 7.2.2
RUN  apk add --no-cache \
	ca-certificates \
	less \
	ncurses-terminfo-base \
	krb5-libs \
	libgcc \
	libintl \
	libssl1.1 \
	libstdc++ \
	tzdata \
	userspace-rcu \
	zlib \
	icu-libs && \
	apk -X https://dl-cdn.alpinelinux.org/alpine/edge/main add --no-cache lttng-ust && \
	curl -L https://github.com/PowerShell/PowerShell/releases/download/v7.2.2/powershell-7.2.2-linux-alpine-x64.tar.gz -o /tmp/powershell.tar.gz && \
	mkdir -p /opt/microsoft/powershell/7 && \
	tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 && \
	rm /tmp/powershell.tar.gz && \
	chmod +x /opt/microsoft/powershell/7/pwsh && \
	ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
	pwsh -version

# Install Azure CLI (https://github.com/Azure/azure-cli/issues/19591)
RUN  apk add py3-pip && \
	apk add gcc musl-dev python3-dev libffi-dev openssl-dev cargo make && \
	pip install --upgrade pip && \
	pip install azure-cli

# Create non-root user
RUN  adduser -h /home/installer -s /bin/sh -D installer
USER installer

# Install kubectl versions (configure for 1.21 by default)
RUN  mkdir /home/installer/bin && \
	echo PATH=$PATH:/home/installer/bin > /home/installer/.profile && \
	curl -L https://dl.k8s.io/release/v1.19.0/bin/linux/amd64/kubectl -o /home/installer/bin/kubectl-v1.19 && \
	curl -L https://dl.k8s.io/release/v1.20.0/bin/linux/amd64/kubectl -o /home/installer/bin/kubectl-v1.20 && \
	curl -L https://dl.k8s.io/release/v1.21.0/bin/linux/amd64/kubectl -o /home/installer/bin/kubectl-v1.21 && \
	chmod +x /home/installer/bin/kubectl-v1.19 /home/installer/bin/kubectl-v1.20 /home/installer/bin/kubectl-v1.21 && \
	ln -s /home/installer/bin/kubectl-v1.21 /home/installer/bin/kubectl

WORKDIR /home/installer

CMD ["/bin/sh", "-l"]
