# Sequin for Railway: the official image, pinned by version and digest, plus a small start script.
# Bump both the tag and the digest together (see CHANGELOG.md).
FROM sequin/sequin:v0.14.6@sha256:336759c1c632ebdc87939bcea70b26b46df6593e666088e1bf29058209437d3e

COPY --chown=app:app --chmod=755 railway-start.sh /scripts/railway-start.sh

EXPOSE 7376
ENTRYPOINT ["/scripts/railway-start.sh"]
