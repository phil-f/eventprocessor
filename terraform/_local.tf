locals {
  config = [
    {
      "name" : "app-1",
      "delay_ms" : 1000,
      "max_concurrency" : 2,
      "timeout_in_seconds" : 10,
      "max_retries" : 2,
      "expires_in_hours" : 24,
      "schedule_start" : "30 5 * * ? *",
      "schedule_end" : "30 2 * * ? *",
      "callee_url" : "https://callee1.com",
      "oauth2_scope" : "write:callee1"
    },
    {
      "name" : "app-2",
      "delay_ms" : 1300,
      "max_concurrency" : 2,
      "timeout_in_seconds" : 10,
      "max_retries" : 2,
      "expires_in_hours" : 24,
      "schedule_start" : "30 4 * * ? *",
      "schedule_end" : "30 3 * * ? *",
      "callee_url" : "https://callee2.com",
      "oauth2_scope" : "write:callee2"
    },
    {
      "name" : "app-3",
      "delay_ms" : 1600,
      "max_concurrency" : 2,
      "timeout_in_seconds" : 10,
      "max_retries" : 2,
      "expires_in_hours" : 24,
      "schedule_start" : "30 3 * * ? *",
      "schedule_end" : "30 4 * * ? *",
      "callee_url" : "https://callee3.com",
      "oauth2_scope" : "write:callee3"
    }
  ]
}
