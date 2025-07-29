# K6

Ce répertoire contient un script de tests de charge utilisant l'outil [k6](https://k6.io/).

## Prérequis
- Installer k6 : https://grafana.com/docs/k6/latest/set-up/install-k6/
- Avoir un accès réseau à l'URL cible.

## Exemple

```shell
k6 run --env VUS=10 \
	--env DURATION=2m \
	--env URL=https://www.wescale.fr \
	wordpress-load.js
```

- `VUS` : nombre d'utilisateurs virtuels simultanés
- `DURATION` : durée totale du test
- `URL` : cible à tester
- `wordpress-load.js` : script de test à exécuter


