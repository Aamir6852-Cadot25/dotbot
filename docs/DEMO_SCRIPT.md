# Live demo script (about 7 minutes)

**Before you present**
- Install the latest build (Actions → `dotbot-windows` zip, or `dotbot-apk`).
- Onboard as *Aamir*, goals `Java, DSA, placements`, provider **Offline demo** (works with no Wi-Fi). Switch to Gemini only if the hall's internet is reliable.
- You → **Reset all data**, so the screens start clean.
- Laptop: allow Dotbot notifications; keep the window wide so the side rail shows.

## 1. Hook (30 s)
"Every AI app wants more of your time. Dotbot wants less. It stays quiet, speaks at the right moment, and works to make you independent."

## 2. The agent thinks out loud (1.5 min): **Chat**
1. Type **plan my day**. Point at the live trace: *Think → Act (memory_get) → Act (create_task ×3) → Observe → Answer*.
   "It isn't just generating text; it's using tools. Check the Today tab: the tasks really exist."
2. Type **remember my best friend Rahul loves cricket**, then open You → **Memory**: the fact is there with a delete button. "My data stays on my phone, and I can see and delete everything it knows."
3. Type **I feel lonely**. It logs mood, comforts briefly, then says *call a friend, people first*. "It's designed not to become a crutch."

## 3. A whole day in one minute (2.5 min): You → **Simulate a student's day** → *Start the day*
Narrate as events appear:
- 07:05 morning ritual; the student writes their own intention, and the agent asks **one** question back.
- 10:30 tutor: hint ladder at low mastery; mastery goes up, but **less** because a hint was used.
- **12:30 three tasks overdue, and Dotbot stays silent on purpose.** "This is deliberate non-intervention: it gives me a chance to fix it myself."
- 13:15 the student finishes a task alone, which is the independence we want.
- 14:30 now it nudges, **firm** tone; 15:10 the student acts.
- 19:05 low mood, **gentle** tone, and it sends me towards people.
- 23:30 **self-reflection**: it grades its own nudges and writes tomorrow's strategy.
Open any card's **Reasoning trace** to show the steps.

## 4. Proof (1.5 min): **Insights**
- KPIs: nudges sent vs times it **chose silence**, and % of nudges acted on.
- Mentor decisions log: every speak/silence with its reason.
- Reflection card: "Strategy for tomorrow…" (it changed its own budget).
- Switch to slides: evaluation table, **3.6 vs 64 messages/day**, 100% low-mood moments answered, and the bug the evaluation caught.

## 5. Learn tab (optional, 30 s)
Ask the tutor a topic and press **Hint** repeatedly: at high mastery it refuses to give the answer ("keep struggling").

## Likely examiner questions
- *Where is the AI vs the rules?* Rules decide **when** (cheap, testable, explainable); the LLM decides **what to say and which tools to use**.
- *What if the API fails?* Every path has an offline fallback; the demo brain speaks the same function-calling protocol.
- *How do you know it works?* 61 automated tests, including a full simulated day, plus a 60-day simulation study against two baselines.
- *Privacy?* SQLite on-device, key in secure storage, Memory page with delete, no lock-screen or accessibility permissions.
