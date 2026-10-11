# Annotator guide (one page)

**What you are doing.** You will see raw sleep-diary entries as participants typed them.
For each one, decide whether the entry **as typed** gives the bedtime, sleep time, wake
time, get-up time, or the two durations the person most likely meant. You will not see
what any program did with the entries. Work alone and do not compare with the other
annotator until you are both finished.

**What you see.** One row per item: bed time and AM/PM, sleep time and AM/PM, awake time
and AM/PM, get-up time and AM/PM, the typed latency ("SOL") and the typed minutes awake
in the night ("WASO"). Empty cells are empty answers.

**What to write in `error_present`.**

| Write | When |
|---|---|
| **Y** | at least one typed time or duration is wrong, i.e. it does not give what the person most likely meant |
| **N** | everything reads as a plausible night as typed, even if the formatting is odd |
| **U** | you cannot tell from this row |

Optional: in `error_type` write one of `ampm`, `transposed`, `colon_or_format`,
`duration_in_clock_format`, `window_contradiction`, `implausible`, `other`; in
`intended_value_or_note` write what you think was meant. In `seconds_taken` write how long
the item took you (rough seconds).

**Examples (made up).**

| Typed | Write | Why |
|---|---|---|
| bed 11:20 PM, sleep 11:45 PM, awake 6:30 AM, get-up 6:50 AM, SOL 25, WASO 10 | N | a normal night |
| bed 11:20 PM, sleep 11:45 **AM**, awake 6:30 AM, get-up 6:50 AM | Y, `ampm` | sleep 12 hours after bed; almost certainly PM |
| bed 11:30 PM, sleep **6:10 AM**, awake **11:50 PM**, get-up 6:10 AM | Y, `transposed` | sleep and awake times in each other's fields |
| bed 10:00 PM, sleep 10:30 PM, awake 6:00 AM, SOL **"11:30"** | Y, `duration_in_clock_format` | a clock time where minutes were asked |
| bed "1130" PM, sleep 11:50 PM, awake 6:30 AM | N | a missing colon still reads as 11:30 |
| bed 10:00 PM, sleep 10:20 PM, awake 6:00 AM, SOL **200** | Y, `window_contradiction` | 200 minutes to fall asleep, but bed to sleep is 20 minutes |

**Rules of thumb.** Judge each row on its own; do not try to guess the study. If a value
could be a real unusual night (for example 3 hours to fall asleep after a late coffee
and the times agree), write **N**. If two readings are about equally likely, write **U**.
Do not look for patterns across items.

**When you finish.** Save the file under its original name and send it to the person who
holds the key. Do not send it to the other annotator.
