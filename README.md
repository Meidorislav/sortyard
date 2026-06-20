# Sortyard

A sorting center simulation model built for [Robozon](https://ozon-robozon.ru/) — a hackathon by Ozon.

The goal is to simulate the movement of goods, containers, and key flows inside a sorting center. The model reveals how core processes are organized, where bottlenecks arise, and how efficiency can be improved through better process design and automation.

## Getting started

```bash
make up        # build and start all services
make down      # stop and remove containers
make logs      # tail logs from all services
make clean     # remove containers and volumes (wipes DB!)
make help      # full list of commands
```

Requires Docker and Docker Compose.
