FROM alpine:latest

COPY scripts/frr-start.sh /

RUN apk add frr && \
	sed -i "s/bgpd=no/bgpd=yes/g" /etc/frr/daemons && \
	sed -i "s/ospfd=no/ospfd=yes/g" /etc/frr/daemons && \
	sed -i "s/isisd=no/isisd=yes/g" /etc/frr/daemons && \
	chmod +x /frr-start.sh

CMD [ "/frr-start.sh" ]
