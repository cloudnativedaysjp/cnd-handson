# Co-located Hands-on Event by CNDS2024 Committee
『一日で学ぶクラウドネイティブ技術実践ハンズオン』by CloudNative Days Summer 2024 実行委員会のドキュメントです。

このハンズオンでは、Docker・Kubernetes・Prometheus・Grafana・OpenTelemetry・Argo CD・Argo Rollouts・Istio・Cilium・Hubble といったよく利用されるクラウドネイティブな OSS について触れることができるハンズオンです。
これらの OSS についての第一歩を学び、これから先の学習のきっかけにしてください。


## Chapter
準備用chapter1＋全10chapterから構成されています。
- [chapter00_setup](./chapter00_setup/)
- [chapter01_cluster-create](./chapter01_cluster-create/)
- [chapter02_docker](./chapter02_docker/)
- [chapter03_kubernetes](./chapter03_kubernetes/)
- [chapter04_prometheus](./chapter04_prometheus/)
- [chapter05_grafana](./chapter05_grafana/)
- [chapter06_opentelemetry](./chapter06_opentelemetry/)
- [chapter07_argocd](./chapter07_argocd/)
- [chapter_istio](./chapter_istio/)
- [chapter09_cilium](./chapter09_cilium/)
- [chapter10_argo-rollouts](./chapter10_argo-rollouts/)
- [chapter_istio-ambientmesh](./chapter_istio-ambientmesh/)
- [chapter12_hubble](./chapter12_hubble/)

### 進め方
まずは、chapter00, chapter01を実施してhandsonを進めるための環境を構築してください。<br>
その後は、順番にchapterを進めることはもちろん、下記フローチャートのように、気になる技術に焦点を当てたchapterを進めることもできます。

```mermaid
flowchart TD
    setup[chapter00_setup]
    cluster[chapter01_cluster-create]
    docker[chapter02_docker]
    k8s[chapter03_kubernetes]
    prom[chapter04_prometheus]
    grafana[chapter05_grafana]
    otel[chapter06_opentelemetry]
    argocd[chapter07_argocd]
    istio[chapter_istio]
    cilium[chapter09_cilium]
    argorollouts[chapter10_argo-rollouts]
    istioambient[chapter_istio-ambientmesh]
    hubble[chapter12_hubble]

    setup-->cluster
    cluster-->docker
    docker-->k8s
    cluster-->prom
    cluster-->argocd

    prom-->grafana
    prom-->argorollouts
    prom-->istio
    argocd-->prom

    grafana-->otel
    grafana-->cilium

    cilium-->hubble

    istio-->istioambient
```

## 免責事項
本ドキュメントに掲載された内容によって生じた損害等の一切の責任を負いかねます。
また、本ドキュメントのコンテンツや情報において、可能な限り正確な情報を掲載するよう努めていますが、情報が古くなったりすることもあります。必ずしも正確性を保証するものではありません。あらかじめご了承ください。
