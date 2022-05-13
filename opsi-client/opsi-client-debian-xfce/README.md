# Build
```
docker build -t opsi-client-debian-xfce .
```

# Export image
```
# Uncompressed
docker save opsi-client-debian-xfce -o opsi-client-debian-xfce.tar
# Compressed with gzip
docker save opsi-client-debian-xfce | gzip > opsi-client-debian-xfce.tar.gz
```

# Import image
```
docker load -i opsi-client-debian-xfce.tar*
```

# Run
```
docker-compose up
```

# Remove containers
```
# Stop and remove containers and networks
docker-compose down
# Stop and remove containers, networks and volumes
docker-compose down -v
```
