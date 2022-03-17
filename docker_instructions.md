* If you use Atom, get the Dockerfile specific grammar (may need to restart Atom to see effect)
```bash
apm install language-docker
```
* Files and directories that should not be included in the image should be put in the `.dockerignore` file
* Bash into running container
```bash
docker-compose exec web bash
```
