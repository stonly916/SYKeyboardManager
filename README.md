# SYKeyboardManager
自动适应在ScrollView中的keyboard弹出、键盘弹出管理

# 使用方法

<pre><code>
#import "SYKeyboardManager" 
//在开启时调用,可以直接在AppDelegate中调用
[[SYKeyboardManager sharedManager] setEnable:YES];
//关闭时调用
[[SYKeyboardManager sharedManager] setEnable:NO];
</code></pre>
