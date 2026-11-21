# aic-dc-site

The AIC Deployment Commitments project page: **https://aic-dc.net/**.
Served by GitHub Pages from the root of `main`. Built in the estate by `DC-Site/build.py --release`;
nothing here is edited by hand.

Publish a rebuilt page (on Em's word only): `./publish.sh` (or `./publish.sh --dry-run` first).
It refuses unless every file matches `DC-Site/site-manifest.txt`.

Never change the custom domain in GitHub's Pages settings: GitHub then commits its own `CNAME`.
