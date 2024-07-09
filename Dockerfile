FROM --platform=$BUILDPLATFORM alpine:3.19 as build

#LABEL maintainer="My Company Team <email@example.org>"
ARG TERRAFORM_VERSION=1.9.1
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

# What's going on here?
# - Download the indicated release along with its checksums and signature for the checksums
# - Verify that the checksums file is signed by the Hashicorp releases key
# - Verify that the zip file matches the expected checksum
# - Extract the zip file so it can be run

RUN apk --quiet --update-cache upgrade
RUN apk add --quiet --no-cache --upgrade git curl openssh gnupg perl-utils zip wget && \
    curl --silent --remote-name https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip && \
    curl --silent --remote-name https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig && \
    curl --silent --remote-name https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS && \
    curl --silent --remote-name https://keybase.io/hashicorp/pgp_keys.asc && \
    gpg --import pgp_keys.asc && \
    gpg --verify terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig terraform_${TERRAFORM_VERSION}_SHA256SUMS && \
    shasum --algorithm 256 --ignore-missing --check terraform_${TERRAFORM_VERSION}_SHA256SUMS && \
    unzip -qq terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip -d /bin && \
    rm -f terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip terraform_${TERRAFORM_VERSION}_SHA256SUMS* pgp_keys.asc

RUN if [ "$TARGETARCH" = "amd64" ]; \
	then export SSM_PLATFORM="ubuntu_64bit"; \
	else export SSM_PLATFORM="ubuntu_arm64"; \
	fi; \
    wget https://s3.amazonaws.com/session-manager-downloads/plugin/latest/$SSM_PLATFORM/session-manager-plugin.deb -q

FROM ubuntu:latest
ARG TERRAFORM_VERSION=1.9.1
ARG SSM_PLATFORM
ARG TARGETARCH

ENV PATH="/root/.local/bin:$PATH"

WORKDIR /opt/savi

ADD https://gitsecret.jfrog.io/artifactory/api/gpg/key/public git-secrets-key

#RUN sh -c "echo 'deb https://gitsecret.jfrog.io/artifactory/git-secret-deb git-secret main' >> /etc/apt/sources.list" && \
#    cat git-secrets-key | apt-key add -

RUN apt-get update && \
    apt-get install -y python3 pip make git openssh-client git-secret jq python3-venv curl && \
    curl -s -L -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${TARGETARCH} && \
    chmod 755 /usr/local/bin/yq

RUN if [ "${TARGETARCH}" = "arm64" ]; \
    then export ARCH_ENV=aarch64; \
    else export ARCH_ENV=x86_64; \
    fi && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    aws --version

RUN pip install ansible==9.4.0 boto3 --break-system-packages

COPY --from=build  session-manager-plugin.deb session-manager-plugin.deb
RUN dpkg -i session-manager-plugin.deb && rm session-manager-plugin.deb

ADD https://install.python-poetry.org poetry.sh
RUN cat poetry.sh | python3 - && rm poetry.sh

COPY --from=build ["/bin/terraform", "/bin/terraform"]

COPY ./config /root/.aws/

RUN ln -s /usr/bin/python3 /usr/bin/python

