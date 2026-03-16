# Using AI.

## prompt
```
generate a image of with text, image and QR code using this text  “I need Help”, size of credit card.  QR code will open blank webpage display the text using this html code:
<!doctype html><meta charset=utf-8><body style="margin:0;display:grid;place-items:center;height:100vh;font:48px Arial">I need Help
```

But this only works, if the reading device understands the "data:" url

## Better option

create a website which responses. when Embedded code into QR code sends
 - https://yourdomain.example/message.html?text=I%20need%20Help

```
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Message</title>
<style>
html, body {
  margin: 0;
  height: 100%;
  background: #fff;
  font-family: Arial, sans-serif;
}
body {
  display: flex;
  align-items: center;
  justify-content: center;
}
#msg {
  font-size: clamp(28px, 8vw, 56px);
  color: #111;
  text-align: center;
  padding: 24px;
}
</style>
</head>
<body>
<div id="msg"></div>
<script>
  const text = new URLSearchParams(location.search).get("text") || "";
  document.getElementById("msg").textContent = text;
</script>
</body>
</html>

```

