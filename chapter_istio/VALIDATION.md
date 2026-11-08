# Istio章の更新調査・kind検証

確認日: 2026-11-08（JST）。対象は `chapter_istio` と `chapter_istio-ambient-mode`。演習の構成、既存の画像、Istio APIによるルーティング手順は維持した。

## 共通Envoy GatewayとGET限定への追加更新

元のL7ポリシー（Git HEAD）も、POST / PUT / PATCH / DELETEの4種類を拒否するDENYだった。「GETのみ許可」という元の文章とは一致していなかったため、両章とも `DENY` の `notMethods: [GET]` に修正した。対象のcurl ServiceAccountからport 8080への通信に範囲を限定し、他の送信元の許可状態を維持する（[公式仕様](https://istio.io/latest/docs/reference/config/security/authorization-policy/#Operation)）。

現在のcluster-createに合わせ、サイドカー章の外部入口は共通のEnvoy Gateway（80番）とした。既存のVirtualService / DestinationRule演習を維持するため、後段にClusterIPのIstio Ingress Gatewayを置く。HTTPRouteの転送先を切り替え、宛先namespaceのReferenceGrantでService参照を許可する。Kialiも共通Gateway経由で公開する。ambient章は専用kindでの学習構成を維持する。

追加検証は同じMacのColima VM上で実施した。サイドカー章は共通章のCilium・Envoy Gateway・Prometheusを導入し、全機能を共通の80番入口で再検証した。ambientは新規kindにmeshコンポーネントを導入して変更したL7認可を検証した。ambientのKiali・メトリクスは下記の初回検証の結果である。

| 追加確認 | 実測結果 |
| --- | --- |
| 共通GatewayのHTTPRoute | Accepted=True、ResolvedRefs=True。転送先はistio-system/istio-ingressgateway:18080 |
| Istio Ingress Gateway | ClusterIP。専用NodePortなし |
| 50:50 / 0:100 | 200回中blue 94回・yellow 106回。切り替え後は50回すべてyellow |
| ヘッダー / リダイレクト | alpha1はyellow、beta1はblue、ヘッダーなしは302 |
| 障害注入 | 遅延20回中10回が約5秒、502障害100回中78回が502 |
| 外部通信 / L4認可 | ServiceEntry追加前000・追加後200。curl-allow 200・curl-deny 403 |
| GET限定（両章） | GET 200、POST / PUT / PATCH / DELETE / HEAD / OPTIONS 403 |
| 拒否対象の範囲 | サイドカー章は外部入口からのPOSTが200、ambientは別ServiceAccountのPOSTが200 |
| ambientの境界確認 | 適用前はHEAD / OPTIONSとも200、適用後は403 |
| Kiali | 共通Gateway経由で状態APIが応答 |
| 終了手順 | HTTPRouteを元のアプリ直結に戻し、ReferenceGrantを削除。80番入口の `/color` が200・blue |

追加検証のJSON・ログは `/private/tmp/istio-tools/followup-*` に保存した。

## 更新した内容

| 対象 | 更新前 → 更新後 | 理由 |
| --- | --- | --- |
| Istio全チャート | 1.29.1 → 1.31.4 | 1.29はサポート終了。1.31.4は確認日時点の最新安定版で、認可などのセキュリティ修正を含む |
| Istio Helm配布先 | Google Storage → `https://blob.istio.io/istio-release/charts` | 1.31以降は旧配布先に新しい成果物が公開されない |
| Kiali | 2.24.0 → 2.34.1 | 確認日時点の最新チャート。Istio 1.31の対応範囲はKiali 2.31以降 |
| ambientのkindノード | Kubernetes 1.31.0 → 1.36.4（digest固定） | Istio 1.31の対応範囲内にし、共通クラスター章とそろえる |
| ambientのGateway API | 1.5.1 → 1.7.0 | 最新安定版のstandard CRDでwaypointを確認 |
| ambientのPrometheusチャート | 83.7.0 → 93.1.0 | 最新のkube-prometheus-stackで収集とKiali連携を確認 |

ambientでは公式の `profile: ambient` を使用し、CNIのリソース設定を現在のチャートの階層へ移動した。古いTelemetry設定は削除した。Istio baseのnamespaceを明示し、base → istiod → CNI → ztunnelの依存順序を設定した。

本文は、旧コンポーネント名の説明、重複した出力・削除コマンド、L7 DENYポリシーの説明、`REGISTRY_ONLY`とcurlの`000`の意味、waypointの対象とクリーンアップを必要な範囲で修正した。

## 初回の検証環境と結果

このMac（arm64）のローカルkindで新規インストールを検証した。kind 0.33.0、Helm 4.3.1、helmfile 1.8.3、kubectl 1.37.2はbrew導入済みのものを使用。初回ambient検証ではHelm 3.19.5も使用した。

既存Docker Desktop 20.10.10のカーネル5.10.47ではBTFがなくCilium 1.20.4が動作しなかったため、別のColima 0.10.3 / Lima 2.3.0 VM（Linux 6.8.0-117、cgroup v2、Docker 29.5.2）を作成した。最終検証ではリポジトリのkind設定に追加の互換性設定を加えていない。

サイドカー章は共通章の3ノード構成、Cilium 1.20.4、Envoy Gateway 1.9.1、Prometheusチャート92.1.0を使用した。Envoy GatewayのDocker Hub OCIチャート取得が401となったため、同じ1.9.1の[公式install.yaml](https://github.com/envoyproxy/gateway/releases/download/v1.9.1/install.yaml)で共通基盤を導入した。Istio両章のhelmfileは変更後のファイルをそのままsyncした（ambientのARM64イメージ事前取得は後述）。

| サイドカー章の確認 | 実測結果 |
| --- | --- |
| Native Sidecar注入 | 2/2 Running。`istio-init`と`istio-proxy`は1.31.4。後者はinitContainerの `restartPolicy: Always` |
| 基本ルーティング | `/color` が200、blue |
| 50:50ルーティング | 200回中blue 111回、yellow 89回 |
| 0:100への切り替え | 50回すべてyellow |
| HTTPヘッダー / リダイレクト | alpha1はyellow、beta1はblue、ヘッダーなしは302で `/maintenance.html` |
| 5秒遅延（50%） | 20回中10回が4.8秒以上、10回が2秒未満、すべて200 |
| 502障害注入（80%） | 100回中77回が502、23回が200 |
| ServiceEntry | 追加前はcurl終了35 / `000`、追加後は200 |
| L4認可 | curl-allowは200、curl-denyは403 |
| L7認可 | GETは200、POST / PUT / PATCH / DELETEは403 |
| 可視化 | Kialiの公開HTTPRoute経由でAPI応答。グラフに3ノード・2エッジ。Prometheusに200 / 403 / 502のメトリクス |
| 最終クリーンアップ | ラベル削除・再起動後、proxyのない1/1 Ready Pod |

| ambient章の確認 | 実測結果 |
| --- | --- |
| インストール | 2ノードReady。istiod / CNI / ztunnelは1.31.4、Kialiは2.34.1、Prometheusは3.16.0。全Helm release deployed |
| プロファイル / CNI設定 | `PILOT_ENABLE_AMBIENT=true`、`AMBIENT_ENABLED=true`。CNIのrequests/limitsは200m・256Miで反映 |
| アプリ単体の確認 | port-forwardで200。Podは1/1でproxy注入なし |
| L4認可 | 適用前は両方200。適用後はallowが200、denyが`000` / curl終了56 |
| ztunnelログ | ポリシー名を含む拒否ログとHBONEの401を確認 |
| L4可視化 | KialiにTCPグラフ（3ノード・2エッジ） |
| waypoint / L7認可 | GatewayはProgrammed=True。GETは200、POST / PUT / PATCH / DELETEは403 |
| waypointログ | `layer7-authz` によるRBAC拒否、response_code 403 |
| L7可視化 | 最新グラフにwaypointを含む4ノード・4エッジ、HTTP/TCP経路。初回はL4のキャッシュが返ったため再取得して確認 |
| メトリクス / Kiali状態 | HTTP 200/403とTCPメトリクスを収集。istiod・2つのztunnel・waypointの収集先4件がすべてUP。Kiali警告なし |
| クリーンアップ | waypoint・ポリシー・curl Podを削除、use-waypointラベルも削除。アプリだけがReadyで残ることを確認 |

Kialiは状態API・グラフAPIとPrometheusの実データで検証した。ブラウザー操作用ホストが利用できず、画面上の操作と既存スクリーンショットの見た目の比較は実施していない。

検証用に作成したkindクラスターと追加のColima VM・コンテナデータは削除済み。実測JSONと詳細ログはこのMacの `/private/tmp/istio-tools/` に保存した。

## arm64でのPrometheus Operatorの取得

確認日時点の `prometheus-operator:v0.95.1` と `prometheus-config-reloader:v0.95.1` は、公式OCI index内のARM64用manifestにも `architecture: amd64` が指定されており、通常のpullでは `no match for platform in manifest` となった。各manifestのconfig blobから実際のARM64イメージを特定し、同一バージョンの公式digestで事前取得した。チャートのバージョンや実行イメージの内容は変更していない。

同じエラーが起きる場合は、クラスター作成後・helmfile sync前に実行する。対象はこの章で作成した2ノードのみ。

```bash
for image in \
  quay.io/prometheus-operator/prometheus-operator@sha256:8f77cb79d1846f3b99319ca2bafda45a48da1a9597850d3a4e28f1d0ac0de2fd \
  quay.io/prometheus-operator/prometheus-config-reloader@sha256:83143fd7d7721d2e03a1aedd945dc92e1ef912c79110a4ec3a0d68fe8678355f
do
  repo=${image%@*}
  for node in istio-ambient-control-plane istio-ambient-worker; do
    docker exec "$node" ctr -n k8s.io images pull --platform linux/arm64 "$image"
    docker exec "$node" ctr -n k8s.io images tag --force "$image" "${repo}:v0.95.1"
  done
done
```

## 調査した公式情報

- [Istioのサポート範囲](https://istio.io/latest/docs/releases/supported-releases/)、[1.31.4リリースノート](https://istio.io/latest/news/releases/1.31.x/announcing-1.31.4/)
- [1.31の配布先変更](https://istio.io/latest/news/releases/1.31.x/announcing-1.31/upgrade-notes/)、[公式チャート一覧](https://blob.istio.io/istio-release/charts/index.yaml)
- [ambientのHelmインストール](https://istio.io/latest/docs/ambient/install/helm/)、[waypointの対象と設定](https://istio.io/latest/docs/ambient/usage/waypoint/)
- [Kialiの互換性](https://kiali.io/docs/installation/installation-guide/prerequisites/)、[公式チャート一覧](https://kiali.org/helm-charts/index.yaml)
- [Gateway API 1.7.0](https://github.com/kubernetes-sigs/gateway-api/releases/tag/v1.7.0)、[Prometheusの公式チャート一覧](https://prometheus-community.github.io/helm-charts/index.yaml)
