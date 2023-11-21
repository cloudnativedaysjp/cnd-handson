# CNDT Co-located Hands-on Event 2023
CNDT Co-located ハンズオンイベント2023のドキュメントです。

## Chapter
全10chapterから構成されています。
- [chapter01_cluster-create](./chapter01_cluster-create/)
- [chapter02_prometheus](./chapter02_prometheus/)
- [chapter03_grafana](./chapter03_grafana/)
- [chapter04a_opentelemetry](./chapter04a_opentelemetry/)
- [chapter04b_argocd](./chapter04b_argocd/)
- [chapter04c_istio](./chapter04c_istio/)
- [chapter04d_cilium](./chapter04d_cilium/)
- [chapter05b_argo-rollouts](./chapter05b_argo-rollouts/)
- [chapter05c_istio-ambientmesh](./chapter05c_istio-ambientmesh/)
- [chapter05d_hubble](./chapter05d_hubble/)

### 進め方
最初にchapter01、chapter02、chapter03を順に実施してください。<br>
chapter04とchapter05はそれぞれ独立しているため、順番に進めることはもちろん、お好きなchapterだけを実施いただくことも可能です。また、下記のように、気になる技術に焦点を当てたchapterを進めることもできます。

- OpenTelemetry関するchapter
  ```plain text
  chapter01 -> chater02 -> chapter03 -> chapter04a
  ```

- Argo CD/Rolloutsに関するchapter
  ```plain text
  chapter01 -> chater02 -> chapter03 -> chapter04b -> chapter05b
  ```

- Istio/Istio ambient meshに関するするchapter
  ```plain text
    chapter01 -> chater02 -> chapter03 -> chapter04c -> chapter05c
  ```

- Cilium/Hubbleに関するするchapter
  ```plain text
    chapter01 -> chater02 -> chapter03 -> chapter04d -> chapter05d
  ```

## 免責事項
本ドキュメントに掲載された内容によって生じた損害等の一切の責任を負いかねます。
また、本ドキュメントのコンテンツや情報において、可能な限り正確な情報を掲載するよう努めていますが、情報が古くなったりすることもあります。必ずしも正確性を保証するものではありません。あらかじめご了承ください。
