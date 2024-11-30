# Co-located Hands-on Event by CNDW2024 Committee
CloudNative Days Winter 2024 実行委員会による『一日で学ぶクラウドネイティブ技術実践ハンズオン』のドキュメントです。

Docker、Kubernetes、Prometheus、Grafanaなど、クラウドネイティブな環境でよく利用されるOSSを対象としたハンズオンです。このハンズオンを通して、これらのOSSについての基本的な使い方を学び、今後の学習のきっかけにしてください。

## Chapter
準備用chapter＋全15chapterから構成されています。
- [chapter_setup](./chapter_setup/)
- [chapter_cluster-create](./chapter_cluster-create/)
- [chapter_docker](./chapter_docker/)
- [chapter_kubernetes](./chapter_kubernetes/)
- [chapter_prometheus](./chapter_prometheus/)
- [chapter_grafana](./chapter_grafana/)
- [chapter_opentelemetry](./chapter_opentelemetry/)
- [chapter_argocd](./chapter_argocd/)
- [chapter_istio](./chapter_istio/)
- [chapter_cilium](./chapter_cilium/)
- [chapter_argo-rollouts](./chapter_argo-rollouts/)
- [chapter_istio-ambient-mode](./chapter_istio-ambient-mode/)
- [chapter_hubble](./chapter_hubble/)
- [chapter_loki](./chapter_loki/)
- [chapter_tempo](./chapter_tempo/)
- [chapter_pyroscope](./chapter_pyroscope/)

### 進め方
まずは、`chapter_setup`, `chapter_cluster-create`を実施してhandsonを進めるための環境を構築してください。<br>
その後は、順番にchapterを進めることはもちろん、下記フローチャートのように、気になる技術に焦点を当てたchapterを進めることもできます。

```mermaid
flowchart TD
    setup[chapter_setup]
    cluster[chapter_cluster-create]
    docker[chapter_docker]
    k8s[chapter_kubernetes]
    prom[chapter_prometheus]
    grafana[chapter_grafana]
    otel[chapter_opentelemetry]
    argocd[chapter_argocd]
    istio[chapter_istio]
    cilium[chapter_cilium]
    argorollouts[chapter_argo-rollouts]
    istioambient[chapter_istio-ambient-mode]
    hubble[chapter_hubble]
    loki[chapter_loki]
    tempo[chapter_tempo]
    pyroscope[chapter_pyroscope]

    setup-->cluster
    cluster-->docker
    docker-->k8s
    cluster-->prom
    cluster-->argocd

    prom-->grafana
    prom-->argorollouts
    prom-->istio

    grafana-->otel
    grafana-->cilium
    grafana-->pyroscope

    otel-->loki
    otel-->tempo

    cilium-->hubble

    istio-->istioambient
```

## 免責事項
本ドキュメントに掲載された内容によって生じた損害等の一切の責任を負いかねます。
また、本ドキュメントのコンテンツや情報において、可能な限り正確な情報を掲載するよう努めていますが、情報が古くなったりすることもあります。必ずしも正確性を保証するものではありません。あらかじめご了承ください。
