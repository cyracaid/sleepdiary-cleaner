# make_scenarios.R -- build the typing-task scenarios and the participant form.
#
# Each scenario is a short story about one night with known bed, sleep, awake and
# get-up times and known latency and wake-after-sleep-onset minutes. A participant
# reads the story and types the times and durations into a diary-style form. What was
# typed is compared with what the story said, so every typing error has a known truth
# that no one on the project chose.
#
# Writes scenarios.csv (the truth) and typing_task_form.html (a single self-contained
# page: no network, no server; it saves the answers as a CSV on the participant's
# computer, to be sent back to the study team).
#
# Usage (from the repository root):
#   Rscript validation/typing_task/make_scenarios.R [--n=40] [--seed=20261011]
args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) as.numeric(sub(paste0("^--", name, "="), "", hit[1])) else default
}
n <- opt("n", 40); seed <- opt("seed", 20261011)
here <- if (dir.exists("validation/typing_task")) "validation/typing_task" else "."
set.seed(seed)

fmt12 <- function(m) {                       # minutes since midnight -> "hh:mm AM/PM"
  m <- m %% 1440; h <- m %/% 60; mi <- m %% 60
  sprintf("%d:%02d %s", ifelse(h %% 12 == 0, 12, h %% 12), mi, ifelse(h < 12, "AM", "PM"))
}
spoken <- function(m) {                      # a few spoken forms, only on quarter hours
  m <- m %% 1440; h <- m %/% 60; mi <- m %% 60
  if (m == 0) return("midnight")
  h12 <- ifelse(h %% 12 == 0, 12, h %% 12); ap <- ifelse(h < 12, "in the morning", ifelse(h < 18, "in the afternoon", "in the evening"))
  nxt <- ifelse((h + 1) %% 12 == 0, 12, (h + 1) %% 12)
  switch(as.character(mi),
         "0"  = sprintf("%d o'clock %s", h12, ap),
         "15" = sprintf("a quarter past %d %s", h12, ap),
         "30" = sprintf("half past %d %s", h12, ap),
         "45" = sprintf("a quarter to %d %s", nxt, ap),
         fmt12(m))
}
say <- function(m, use_spoken) if (use_spoken && (m %% 1440) %% 15 == 0) spoken(m) else fmt12(m)

sc <- data.frame(scenario_id = sprintf("S%02d", seq_len(n)))
bed   <- sample(seq(21 * 60, 25.5 * 60, by = 5), n, replace = TRUE)       # 9:00 PM to 1:30 AM
tib   <- sample(seq(7 * 60, 9.5 * 60, by = 5), n, replace = TRUE)
sol   <- sample(seq(5, 60, by = 5), n, replace = TRUE)
waso  <- sample(seq(0, 60, by = 10), n, replace = TRUE)
sleep <- bed + sol
awake <- bed + tib
getup <- awake + sample(seq(5, 30, by = 5), n, replace = TRUE)
use_sp <- runif(n) < 0.25
sc$bed_min <- bed %% 1440; sc$sleep_min <- sleep %% 1440
sc$awake_min <- awake %% 1440; sc$getup_min <- getup %% 1440
sc$sol_min <- sol; sc$waso_min <- waso
for (k in c("bed", "sleep", "awake", "getup")) {
  v <- get(k)
  sc[[paste0(k, "_text")]] <- fmt12(v)
  sc[[paste0(k, "_ampm")]] <- ifelse((v %% 1440) < 720, "AM", "PM")
}
sc$story <- vapply(seq_len(n), function(i) {
  night <- if (waso[i] == 0) "You did not wake up during the night." else
    sprintf("During the night you were awake for about %d minutes in total.", waso[i])
  sprintf("You got into bed at %s. It took you about %d minutes to fall asleep. %s You woke up for the last time at %s and got out of bed at %s.",
          say(bed[i], use_sp[i]), sol[i], night, say(awake[i], use_sp[i]), say(getup[i], use_sp[i]))
}, character(1))
write.csv(sc, file.path(here, "scenarios.csv"), row.names = FALSE)

# ---- the participant form ----------------------------------------------------
esc <- function(x) gsub('"', '\\\\"', x, fixed = TRUE)
json <- paste0("[", paste(sprintf('{"id":"%s","story":"%s"}', sc$scenario_id, esc(sc$story)),
                          collapse = ","), "]")
html <- c(
'<!doctype html><html lang="en"><head><meta charset="utf-8">',
'<meta name="viewport" content="width=device-width, initial-scale=1">',
'<title>Sleep diary typing task</title><style>',
'body{font-family:system-ui,sans-serif;max-width:640px;margin:2rem auto;padding:0 1rem;line-height:1.5}',
'label{display:block;margin:.6rem 0 .2rem;font-weight:600}input[type=text]{padding:.4rem;width:9rem;font-size:1rem}',
'.story{background:#f3f5f7;padding:1rem;border-radius:8px}.row{display:flex;gap:1rem;align-items:center}',
'button{margin-top:1.2rem;padding:.6rem 1.2rem;font-size:1rem}.small{color:#555;font-size:.9rem}',
'</style></head><body><h1>Sleep diary typing task</h1>',
'<div id="intro"><p>You will read a short description of one night and then fill in a sleep diary as if it were your own night. Type the answers the way you normally would. There are no trick questions and nothing is graded as right or wrong for you.</p>',
'<label for="pid">Your participant code</label><input type="text" id="pid" autocomplete="off">',
'<button id="start">Start</button></div>',
'<div id="task" hidden><p class="small" id="count"></p><div class="story" id="story"></div>',
'<label>What time did you get into bed?</label><div class="row"><input type="text" id="bed" placeholder="hh:mm">',
'<span><label style="display:inline"><input type="radio" name="bed_ap" value="AM"> AM</label> <label style="display:inline"><input type="radio" name="bed_ap" value="PM"> PM</label></span></div>',
'<label>What time did you fall asleep?</label><div class="row"><input type="text" id="sleep" placeholder="hh:mm">',
'<span><label style="display:inline"><input type="radio" name="sleep_ap" value="AM"> AM</label> <label style="display:inline"><input type="radio" name="sleep_ap" value="PM"> PM</label></span></div>',
'<label>What time did you wake up for the last time?</label><div class="row"><input type="text" id="awake" placeholder="hh:mm">',
'<span><label style="display:inline"><input type="radio" name="awake_ap" value="AM"> AM</label> <label style="display:inline"><input type="radio" name="awake_ap" value="PM"> PM</label></span></div>',
'<label>What time did you get out of bed?</label><div class="row"><input type="text" id="getup" placeholder="hh:mm">',
'<span><label style="display:inline"><input type="radio" name="getup_ap" value="AM"> AM</label> <label style="display:inline"><input type="radio" name="getup_ap" value="PM"> PM</label></span></div>',
'<label>How long did it take you to fall asleep? (minutes)</label><input type="text" id="sol">',
'<label>How long were you awake during the night in total? (minutes)</label><input type="text" id="waso">',
'<button id="next">Next</button></div>',
'<div id="done" hidden><h2>Finished</h2><p>Thank you. Press the button to save your answers, then send the file to the study team.</p><button id="save">Save my answers</button></div>',
paste0('<script>const S=', json, ';'),
'let i=0,t0=0;const R=[];const $=id=>document.getElementById(id);',
'function show(){$("count").textContent="Night "+(i+1)+" of "+S.length;$("story").textContent=S[i].story;',
' ["bed","sleep","awake","getup","sol","waso"].forEach(k=>$(k).value="");',
' document.querySelectorAll("input[type=radio]").forEach(r=>r.checked=false);t0=Date.now();}',
'$("start").onclick=()=>{if(!$("pid").value.trim()){alert("Please enter your code");return;}$("intro").hidden=true;$("task").hidden=false;show();};',
'$("next").onclick=()=>{const ap=n=>{const c=document.querySelector("input[name="+n+"_ap]:checked");return c?c.value:""};',
' R.push({participant_id:$("pid").value.trim(),scenario_id:S[i].id,bed_time:$("bed").value,bed_ampm:ap("bed"),',
' sleep_time:$("sleep").value,sleep_ampm:ap("sleep"),awake_time:$("awake").value,awake_ampm:ap("awake"),',
' getup_time:$("getup").value,getup_ampm:ap("getup"),sol_typed:$("sol").value,waso_typed:$("waso").value,seconds:Math.round((Date.now()-t0)/1000)});',
' i++;if(i<S.length)show();else{$("task").hidden=true;$("done").hidden=false;}};',
'$("save").onclick=()=>{const k=Object.keys(R[0]);const q=v=>\'"\'+String(v).replace(/"/g,\'""\')+\'"\';',
' const csv=[k.join(",")].concat(R.map(r=>k.map(c=>q(r[c])).join(","))).join("\\n");',
' const a=document.createElement("a");a.href=URL.createObjectURL(new Blob([csv],{type:"text/csv"}));',
' a.download="typing_task_"+R[0].participant_id+".csv";a.click();};',
'</script></body></html>')
writeLines(html, file.path(here, "typing_task_form.html"), useBytes = TRUE)
cat(sprintf("wrote %d scenarios and the form to %s\n", n, here))
