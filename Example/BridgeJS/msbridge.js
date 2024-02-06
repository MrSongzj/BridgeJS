var msBridge = {
  cbCount: 0,
  // 调用原生方法的主要函数
  call: function (method, data, callback) {
    if (typeof data === "function") {
      // 如果第二个参数是方法, 把第二个参数设置到 callback 上, 把参数设置为空对象
      callback = data;
      data = undefined;
    }
    // 给参数套上一层 data 字段
    let info = { data };

    if (typeof callback === "function") {
      // 如果存在回调函数，生成唯一标识符，并将回调函数存储到 window 对象中
      const callbackName = "msbcb" + this.cbCount++;
      window[callbackName] = callback;
      info.callback = callbackName;
    }

    // 调用原生方法并获取返回值
    return prompt("msbridge-" + method, JSON.stringify(info));
  },
  api: {},
  didInit: false,
  addApi: function (name, method) {
    if (typeof method === "function") {
      this.api[name] = method;
    } else {
      Object.keys(method).forEach((key) => {
        if (typeof method[key] === "function") {
          this.api[name + "." + key] = method[key];
        }
      })
    }
    if (!this.didInit) {
      this.didInit = true;
      setTimeout(() => {
        this.call("_init")
      }, 0);
    }
  },
};

function msNaviteCallJavaScript(info) {
  let method = msBridge.api[info.method];
  let data = info.data || [];
  data.push((result, complete) => {
    // 异步方法回调
    msBridge.call("_msJsCallback", JSON.stringify({
      data: result,
      complete: false !== complete ? "1" : "0",
      callback: info.callback
    }));
  });
  const result = method.apply(msBridge.api, data);
  if (result !== undefined) {
    // 调用js的同步方法
    msBridge.call("_msJsCallback", JSON.stringify({
      data: result,
      complete: "1",
      callback: info.callback
    }));
  }
}
