# Analytics Events Baseline

Use these events to build baseline dashboards for adoption and retention.

## Core engagement

- `chat_message_sent`
  - params: `family_id`
- `story_created`
  - params: `family_id`, `has_images`
- `story_commented`
  - params: `family_id`
- `task_created`
  - params: `family_id`, `reward_points`
- `task_submitted`
  - params: `family_id`
- `task_approved`
  - params: `family_id`
- `task_rejected`
  - params: `family_id`
- `quiz_generated`
  - params: `mode`, `question_count`
- `quiz_submitted`
  - params: `score`, `total`

## Recommended dashboard cards

- DAU / WAU
- D1 / D7 retention
- Stories per active family (daily)
- Task funnel (`task_created` -> `task_submitted` -> `task_approved`)
- Quiz completion rate (`quiz_generated` vs `quiz_submitted`)
- Messages per day and active chat days

## Segment suggestions

- By `family_id`
- By role (derive via member profile if needed)
- By free-mode flags (local quiz vs function path)
