chapter05b_argo-rollouts

## Analysis
### JOB
Analysis実行時にjobをデプロイし、jobの実行結果によってPromteするかどうかを判断する
### WEB
Analysis実行時にリクエストを送信し、レスポンスの内容にてよってPromteするかどうかを判断する
* Json形式のレスポンスの場合Jsonの中身を見て判断することが可能
* Json形式以外のレスポンスの場合はstatus codeが200であるかどうかの判断になる
