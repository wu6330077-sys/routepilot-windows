# Performance case study: residential exit plus fast VPS route

This is a sanitized record from the deployment that inspired RoutePilot. It explains the problem and measured outcome; it is not a speed guarantee.

## Before and after

The original path carried everything through the residential upstream:

```text
Windows → Reality over TCP 443 → VPS → residential proxy → Internet
```

The optimized deployment added an independent bulk path:

```text
Protected requests: Windows → Reality TCP 443 → VPS → residential proxy → Internet
Bulk requests:      Windows → Hysteria 2 UDP 443 → VPS → Internet
```

TCP 443 and UDP 443 can coexist on the server because TCP and UDP have separate port spaces. An Edge PAC selects a local HTTP proxy per hostname. For example, the YouTube page and Google account requests stay on the residential path while `googlevideo.com` payloads use the VPS path.

## Test conditions

- Date: 2026-08-02
- Object: the same 5 MB Cloudflare test file for every route
- Method: repeated single transfers summarized by their median, plus one four-transfer aggregate test
- Final Hysteria 2 bandwidth parameters: 80 Mbps down and 20 Mbps up
- Public endpoints, credentials, and provider account details were removed

## Results

| Route | Median single connection | Four-transfer aggregate |
|---|---:|---:|
| Original Reality plus residential forwarding | 7.02 Mbps | 24.02 Mbps |
| Hysteria 2, 30 Mbps setting | 19.16 Mbps | 24.64 Mbps |
| Hysteria 2, 50 Mbps setting | 27.84 Mbps | 37.28 Mbps |
| Hysteria 2, final 80 Mbps setting | **37.93 Mbps** | **57.34 Mbps** |

On like-for-like measurements, the final median single transfer was about 5.4 times the original; the four-transfer aggregate was about 2.4 times the original.

These values are `Mbps`, or megabits per second. Divide by eight for an approximate megabytes-per-second figure before protocol overhead: 57.34 Mbps is roughly 7.17 MB/s.

## Why it improved

The main gain came from moving large payloads around the residential provider and the extra forwarding hop. Hysteria 2 uses UDP/QUIC and can handle latency and loss more efficiently than a nested TCP forwarding path, but it does not create bandwidth. Local access speed, VPS capacity, congestion, distance, loss, and the destination CDN remain hard limits.

RoutePilot performs routing, not bonding. Each hostname goes to one route. Protected hostnames fail closed: if the primary proxy is down, they do not silently fall back to direct access or the VPS. Bulk hostnames do not fall back to the residential route, which helps prevent accidental quota usage.

## Reproducing the comparison

Measure both paths using the same object, number of repetitions, concurrency, and time window. Record single-transfer and aggregate results separately; comparing a single result on one route with a parallel result on the other would exaggerate the improvement. Your result may be higher or lower depending on the networks involved.
