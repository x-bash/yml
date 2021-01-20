yml-value = json-value | yml-dict | yml-array | ~
yml-dict =

yml-dict-kv = yml-dict-key + : + yml-value
yml-list-item = sensible-indent + '-' + yml-value
yml-list = yml-list-item | ( yml-list-item '\n' + yml-list )



json-value = json-dict | json-array | true | false | null
json-dict = { + string + json-value + [ string + json-value + ,]   + }
json-array = [ json-value + [ , + json-value ]  ]


# 开发路线图

1. 支持基本能力，可以读基本的yml配置，例如kubernetes
2. 引入json支持


