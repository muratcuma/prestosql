## Prestosql
```bash
To build your Docker image using the following command; 
$ sudo docker build -t prestosql:${version} .
```

# Default Run Docker

```bash
$ docker run -d -p 8080:8080 --name presto prestosql:${version}
```
