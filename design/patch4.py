import io, sys
sys.stdout.reconfigure(encoding="utf-8")
p = r"D:\xiaodi-push\_preview\zhuxiaojie-ui-opt.html"
s = io.open(p, encoding="utf-8").read()

# 柔光的着色变体
s = s.replace("""  .orbglow{position:absolute;width:150px;height:150px;border-radius:50%;filter:blur(12px);
     background:radial-gradient(circle, rgba(90,140,255,.45) 0%, rgba(150,90,255,.18) 45%, transparent 70%);
     animation:orbpulse 2.2s ease-in-out infinite}""",
"""  .orbglow{position:absolute;width:150px;height:150px;border-radius:50%;filter:blur(12px);
     background:radial-gradient(circle, rgba(90,140,255,.45) 0%, rgba(150,90,255,.18) 45%, transparent 70%);
     animation:orbpulse 2.2s ease-in-out infinite}
  .orbglow.blue{background:radial-gradient(circle, rgba(90,140,255,.62) 0%, rgba(120,170,255,.22) 48%, transparent 72%)}
  .orbglow.red{background:radial-gradient(circle, rgba(255,110,100,.52) 0%, rgba(214,78,74,.20) 48%, transparent 72%)}""", 1)

# 蓝色（转文字）那台
s = s.replace("""            <span class="ringbig r2 blue"></span>
            <span class="ringbig r1 blue"></span>""",
"""            <span class="orbglow blue"></span>
            <span class="ringbig r2"></span>
            <span class="ringbig r1"></span>""", 1)

# 红色（取消）那台
s = s.replace("""            <span class="ringbig r2 red"></span>
            <span class="ringbig r1 red"></span>""",
"""            <span class="orbglow red"></span>
            <span class="ringbig r2"></span>
            <span class="ringbig r1"></span>""", 1)

io.open(p, "w", encoding="utf-8").write(s)
print("orbglow-blue:", s.count("orbglow blue"), " orbglow-red:", s.count("orbglow red"), " 总 orbglow:", s.count("orbglow"))
print("残留 <span class=\"ringbig\" 带色:", s.count("ringbig r2 blue"), s.count("ringbig r2 red"))
