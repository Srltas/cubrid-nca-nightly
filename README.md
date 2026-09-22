# cubrid-nca-nightly

A container image of the CUBRID build published for **NCA** (Next CUBRID Admin)
testing: the engine plus the CUBRID Manager Server that NCA talks to.

Not a release. Not supported. A throwaway testing aid, kept only as long as it
is useful.

```bash
docker run -d -p 33000:33000 -p 8001:8001 ghcr.io/srltas/cubrid-nca-nightly:nightly
```

| port | what |
| --- | --- |
| 33000 | broker, for JDBC and other drivers |
| 8001 | manager server, which is what NCA connects to |

## Tags

| tag | meaning |
| --- | --- |
| `11.4.5.1907-7077e91` | one build, forever. The name comes from the tarball on ftp. |
| `nightly` | the newest build that PASSED the smoke test |
| `latest` | alias of `nightly` |

Which build a moving tag points at:

```bash
docker image inspect ghcr.io/srltas/cubrid-nca-nightly:nightly \
  --format '{{index .Config.Labels "org.cubrid.nightly.build_id"}}'
```

## How it works

The engine is not built here. The package comes from
`ftp.cubrid.org/cubrid_dev/NCA_Nightly/`, which holds a single tarball whose
name carries the build id. This repository only packages it.

Runs are **manual only**: Actions -> NCA test image -> Run workflow. There is no
schedule, because this exists to test a specific build rather than to run
unattended.

## Differences from the engine nightly image

This started as a copy of `Srltas/cubrid-nightly` and diverges in four places.

| | here |
| --- | --- |
| startup | a `NCA` component mode that also runs `cubrid manager start` |
| health | both the engine **and** the manager have to answer |
| ports | 8001 exposed alongside 33000 |
| integrity | no `hash.md5` is published, so the download cannot be verified |

On that last point: the engine nightly checks every download against a digest
published beside it. This source publishes none, so the run records the file's
size and md5 in its summary instead. That does not prove the file is genuine;
it only lets you see that it changed. A truncated download is still caught,
because the run lists the archive before building.

The source also keeps no history: one tarball, replaced in place. Once it is
replaced there is no way to rebuild an older image, so an image published here
is the only remaining copy of that build. Retention keeps 30 versions rather
than the engine nightly's 15 for that reason.

## Throwing it away

Delete the repository. Nothing else depends on it, and no file here is shared
with `Srltas/cubrid-nightly`.
