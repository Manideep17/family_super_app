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

## Gamification surfaces (added to decide keep-vs-sunset — see
## docs/PRODUCT_STRATEGY_AND_ENGAGEMENT.md, "Curate, don't just add")

- `reel_created` — a family member posted a mini reel battle video.
- `creative_submission_posted` — a family member answered the daily
  creative-challenge prompt.
- `time_travel_response_submitted` — a family member responded to a past
  memory in the time-travel game.
- `prediction_created` — a new future-prediction was posted.
- `prediction_resolved`
  - params: `outcome` (`'yes'` or `'no'`)

Watch these four for at least a month of real usage after this ships. If
any of them stay near zero while diary/tasks/vault keep growing, that's the
signal to sunset it rather than keep maintaining a screen nobody uses.

## Recommended dashboard cards

- DAU / WAU
- D1 / D7 retention
- Stories per active family (daily)
- Task funnel (`task_created` -> `task_submitted` -> `task_approved`)
- Quiz completion rate (`quiz_generated` vs `quiz_submitted`)
- Messages per day and active chat days
- Gamification surface usage (`reel_created`, `creative_submission_posted`,
  `time_travel_response_submitted`, `prediction_created`) — one card per
  surface, to compare against each other and against core-feature usage

## Segment suggestions

- By `family_id`
- By role (derive via member profile if needed)
- By free-mode flags (local quiz vs function path)
