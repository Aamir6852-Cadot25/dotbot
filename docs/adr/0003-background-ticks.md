# ADR 0003: Mentor background evaluation
Status: accepted
- Android: workmanager periodic task (15 min minimum) runs `MentorService.tick()` in a background isolate.
- Windows: no OS-level periodic task in v0.1; the app shell ticks on a Timer while running.
- The policy is rule-based and free; the LLM is only called when the policy decides to speak, protecting free-tier quota.
- Silence budget (3 msgs/day, 90 min gap) + 25% deliberate non-intervention on non-urgent nudges (never twice in a row; never for mood or rituals).
