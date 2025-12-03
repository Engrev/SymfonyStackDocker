#!/bin/bash
set -euo pipefail

TARGET=$1
KEEP=${2:-5}          # nombre de releases à garder
SPECIFIC=${3:-""}     # rollback vers release précise

if [ -z "$TARGET" ]; then
  echo "❌ Usage: $0 <prod|pprod> [keep]"
  exit 1
fi

APP_PATH="/var/www/<project_name>/$TARGET" # A REMPLACER
CURRENT="$APP_PATH/current"
RELEASES="$APP_PATH/releases"

if [ ! -d "$RELEASES" ]; then
    echo "❌ Aucun dossier releases trouvé dans $APP_PATH"
    exit 1
fi

CURRENT_RELEASE=$(basename "$(readlink -f $CURRENT)" 2>/dev/null || true)
PREVIOUS_RELEASE=""

if [ -n "$SPECIFIC" ]; then
    if [ -d "$RELEASES/$SPECIFIC" ]; then
      PREVIOUS_RELEASE=$SPECIFIC
    else
      echo "❌ Release $SPECIFIC introuvable."
      exit 1
    fi
else
    RELEASE_LIST=($(ls -1t $RELEASES))
    for rel in "${RELEASE_LIST[@]}"; do
        if [ "$rel" == "$CURRENT_RELEASE" ]; then
          continue
        else
            PREVIOUS_RELEASE=$rel
            break
        fi
    done
fi

if [ -z "$PREVIOUS_RELEASE" ]; then
    echo "❌ Pas de release précédente trouvée."
    exit 1
fi

ln -sfn "$RELEASES/$PREVIOUS_RELEASE" "$CURRENT"
echo "✅ Rollback effectué : $CURRENT pointe maintenant vers $PREVIOUS_RELEASE"

# Suppression de la release cassée
if [ -n "$CURRENT_RELEASE" ]; then
    echo "🗑️ Suppression de la release cassée : $CURRENT_RELEASE"
    rm -rf "$RELEASES/$CURRENT_RELEASE" || true
fi

# Nettoyage
TOTAL=$(ls -1t $RELEASES | wc -l)
if [ "$TOTAL" -gt "$KEEP" ]; then
    echo "🧹 Nettoyage : conservation des $KEEP dernières releases"
    TO_DELETE=$(ls -1t $RELEASES | tail -n +$(($KEEP+1)))
    for rel in $TO_DELETE; do
        echo "   ➜ Suppression $rel"
        rm -rf "$RELEASES/$rel"
    done
fi

echo "✨ Rollback terminé avec succès"
