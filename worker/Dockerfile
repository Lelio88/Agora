# Image du worker Agora (iCal, récurrences, puis Discord).
#
# Construite par la CI (.github/workflows/deploy.yml), jamais sur le serveur,
# qui est partagé : une compilation sur place a déjà saturé sa mémoire.
#
# Choix non évidents :
#   - -mod=vendor : les dépendances sont dans worker/vendor/, la construction
#     ne touche pas le réseau et ne dépend pas d'un proxy de modules ;
#   - distroless/static : ni shell ni gestionnaire de paquets, mais les
#     certificats racine (le worker relit des flux iCal en HTTPS) ; les
#     fuseaux horaires sont embarqués dans le binaire (time/tzdata) ;
#   - pas de HEALTHCHECK Docker (l'image n'a ni curl ni wget) : la CI sonde
#     /healthz sur la boucle locale après chaque déploiement, et
#     « restart: unless-stopped » relance un worker tombé ;
#   - utilisateur nonroot : le worker n'écrit rien sur disque.
#
#   docker build -t agora-worker worker/

FROM golang:1.26-alpine AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -mod=vendor -trimpath -ldflags="-s -w" -o /out/worker ./cmd/worker

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/worker /worker
EXPOSE 8080
ENTRYPOINT ["/worker"]
