FROM golang:1.20 as builder
WORKDIR /tmp/autoenv
COPY . /tmp/autoenv
RUN CGO_ENABLED=0 GOOS=linux go build -o /apps/autoenv ./cmd/autoenv

FROM scratch
COPY --from=builder /apps/autoenv /apps/autoenv
EXPOSE 8080
CMD ["/apps/autoenv"]