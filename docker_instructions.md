* If you use Atom, get the Dockerfile specific grammar (may need to restart Atom to see effect)
```bash
apm install language-docker
```
* Files and directories that should not be included in the image should be put in the `.dockerignore` file
* Build the docker image
```bash
docker compose build
```
* Bash into running container
```bash
docker compose exec web bash
```

Redis huge pages warning - see https://github.com/docker-library/redis/issues/55

Not quite working yet - creates a new container
```bash
docker run -it --privileged --pid=host centos:7
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```
