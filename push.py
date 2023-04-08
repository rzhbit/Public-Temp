from urllib.parse import urlencode
from json import loads

def send_msg_pushdeer(token, title= "test title", Text= "test text"):
    if not token:
        # 无token则拦截推送
        return 'PushDeer: 未配置token，无法进行消息推送。'
    
    params = {"pushkey": token,
              "text" = Title,
              "desp" = Text,
              "type" : "markdown"}
    
    urldata = urlencode(params)
    
    state_url = f'https://api2.pushdeer.com/message/push?{urldata}'

    count = 1
    while True:
        status_rsp = get(url=state_url)
        result = loads(status_rsp.json()['content']['result'][0])['counts']
        logger.info(f'查询消息推送是否成功ing : {count}')
        if result:
            return '消息推送成功！'
        elif count >= 60:   # 防止程序一直运行
            return '程序运行结束！推送结果未知！'
        count += 1
        sleep(1)
