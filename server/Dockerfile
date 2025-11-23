FROM ubuntu:22.04

# Avoid tzdata prompts
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    gcc make \
    libmysqlclient-dev \
    mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /app

COPY . /app

# Build server
RUN make clean && make

EXPOSE 5555

CMD ["./bin/server"]