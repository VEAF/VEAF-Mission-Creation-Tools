-- Cherry Studio 2.2.3 database schema, for the tests of veaf_libs.ai_clients.setup_cherry.
-- Built by replaying the 42 migrations of CherryHQ/cherry-studio tag v2.2.3
-- (migrations/sqlite-drizzle/0000 to 0041) into an empty SQLite database, then dumping sqlite_master
-- (FTS shadow tables left out: the virtual tables create them).
-- Regenerate it the same way for each Cherry version ai-setup is tested with.
CREATE TABLE `agent` (
	`id` text PRIMARY KEY NOT NULL,
	`type` text NOT NULL,
	`name` text NOT NULL,
	`description` text DEFAULT '' NOT NULL,
	`instructions` text NOT NULL,
	`model` text,
	`plan_model` text,
	`small_model` text,
	`disabled_tools` text DEFAULT '[]' NOT NULL,
	`configuration` text DEFAULT '{}' NOT NULL,
	`order_key` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`deleted_at` integer,
	FOREIGN KEY (`model`) REFERENCES `user_model`(`id`) ON UPDATE no action ON DELETE set null,
	FOREIGN KEY (`plan_model`) REFERENCES `user_model`(`id`) ON UPDATE no action ON DELETE set null,
	FOREIGN KEY (`small_model`) REFERENCES `user_model`(`id`) ON UPDATE no action ON DELETE set null
);
CREATE TABLE `agent_channel_task` (
	`channel_id` text NOT NULL,
	`task_id` text NOT NULL,
	PRIMARY KEY(`channel_id`, `task_id`),
	FOREIGN KEY (`channel_id`) REFERENCES `agent_channel`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`task_id`) REFERENCES `job_schedule`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE `agent_global_skill` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`description` text,
	`folder_name` text NOT NULL,
	`source` text NOT NULL,
	`source_url` text,
	`namespace` text,
	`author` text,
	`version` text,
	`tags` text DEFAULT '[]' NOT NULL,
	`content_hash` text NOT NULL,
	`is_enabled` integer DEFAULT false NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
, `mirror_enabled` integer DEFAULT true NOT NULL);
CREATE TABLE `agent_skill` (
	`agent_id` text NOT NULL,
	`skill_id` text NOT NULL,
	`is_enabled` integer DEFAULT false NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`agent_id`, `skill_id`),
	FOREIGN KEY (`agent_id`) REFERENCES `agent`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`skill_id`) REFERENCES `agent_global_skill`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE `agent_workspace` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`path` text NOT NULL,
	`type` text DEFAULT 'user' NOT NULL,
	`order_key` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	CONSTRAINT "agent_workspace_type_check" CHECK("agent_workspace"."type" IN ('user', 'system'))
);
CREATE TABLE `app_state` (
	`key` text PRIMARY KEY NOT NULL,
	`value` text NOT NULL,
	`description` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
CREATE TABLE `assistant` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`prompt` text DEFAULT '' NOT NULL,
	`emoji` text NOT NULL,
	`description` text DEFAULT '' NOT NULL,
	`model_id` text,
	`group_id` text,
	`settings` text NOT NULL,
	`order_key` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`deleted_at` integer,
	FOREIGN KEY (`model_id`) REFERENCES `user_model`(`id`) ON UPDATE no action ON DELETE set null,
	FOREIGN KEY (`group_id`) REFERENCES `group`(`id`) ON UPDATE no action ON DELETE set null
);
CREATE TABLE `agent_knowledge_base` (
	`agent_id` text NOT NULL,
	`knowledge_base_id` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`agent_id`, `knowledge_base_id`),
	FOREIGN KEY (`agent_id`) REFERENCES `agent`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`knowledge_base_id`) REFERENCES `knowledge_base`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE `agent_mcp_server` (
	`agent_id` text NOT NULL,
	`mcp_server_id` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`agent_id`, `mcp_server_id`),
	FOREIGN KEY (`agent_id`) REFERENCES `agent`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`mcp_server_id`) REFERENCES `mcp_server`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE `assistant_knowledge_base` (
	`assistant_id` text NOT NULL,
	`knowledge_base_id` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`assistant_id`, `knowledge_base_id`),
	FOREIGN KEY (`assistant_id`) REFERENCES `assistant`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`knowledge_base_id`) REFERENCES `knowledge_base`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE `assistant_mcp_server` (
	`assistant_id` text NOT NULL,
	`mcp_server_id` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`assistant_id`, `mcp_server_id`),
	FOREIGN KEY (`assistant_id`) REFERENCES `assistant`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`mcp_server_id`) REFERENCES `mcp_server`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE `mini_app_logo_file_ref` (
	`id` text PRIMARY KEY NOT NULL,
	`file_entry_id` text NOT NULL,
	`source_id` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`file_entry_id`) REFERENCES `file_entry`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`source_id`) REFERENCES `mini_app`(`app_id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE `painting_file_ref` (
	`id` text PRIMARY KEY NOT NULL,
	`file_entry_id` text NOT NULL,
	`source_id` text NOT NULL,
	`role` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`file_entry_id`) REFERENCES `file_entry`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`source_id`) REFERENCES `painting`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "pfr_role_check" CHECK("painting_file_ref"."role" IN ('output', 'input'))
);
CREATE TABLE `provider_logo_file_ref` (
	`id` text PRIMARY KEY NOT NULL,
	`file_entry_id` text NOT NULL,
	`source_id` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`file_entry_id`) REFERENCES `file_entry`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`source_id`) REFERENCES `user_provider`(`provider_id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE `group` (
	`id` text PRIMARY KEY NOT NULL,
	`entity_type` text NOT NULL,
	`name` text NOT NULL,
	`order_key` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
CREATE TABLE `job_schedule` (
	`id` text PRIMARY KEY NOT NULL,
	`type` text NOT NULL,
	`name` text DEFAULT '' NOT NULL,
	`trigger` text NOT NULL,
	`job_input_template` text NOT NULL,
	`enabled` integer DEFAULT true NOT NULL,
	`next_run` integer,
	`last_run` integer,
	`catch_up_policy` text NOT NULL,
	`metadata` text DEFAULT '{}' NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
CREATE TABLE `job` (
	`id` text PRIMARY KEY NOT NULL,
	`type` text NOT NULL,
	`status` text NOT NULL,
	`priority` integer DEFAULT 0 NOT NULL,
	`queue` text NOT NULL,
	`idempotency_key` text,
	`schedule_id` text,
	`scheduled_at` integer NOT NULL,
	`started_at` integer,
	`finished_at` integer,
	`attempt` integer DEFAULT 0 NOT NULL,
	`max_attempts` integer DEFAULT 3 NOT NULL,
	`input` text NOT NULL,
	`output` text,
	`error` text,
	`parent_id` text,
	`cancel_requested` integer DEFAULT false NOT NULL,
	`metadata` text DEFAULT '{}' NOT NULL,
	`timeout_ms` integer,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL, `cancel_requested_at` integer, `recovery` text,
	FOREIGN KEY (`schedule_id`) REFERENCES `job_schedule`(`id`) ON UPDATE no action ON DELETE set null,
	FOREIGN KEY (`parent_id`) REFERENCES `job`(`id`) ON UPDATE no action ON DELETE set null,
	CONSTRAINT "job_status_check" CHECK("job"."status" IN ('pending','delayed','running','completed','failed','cancelled'))
);
CREATE TABLE `message` (
	`id` text PRIMARY KEY NOT NULL,
	`parent_id` text,
	`topic_id` text NOT NULL,
	`role` text NOT NULL,
	`data` text NOT NULL,
	`searchable_text` text DEFAULT '' NOT NULL,
	`status` text NOT NULL,
	`siblings_group_id` integer DEFAULT 0 NOT NULL,
	`model_id` text,
	`message_snapshot` text,
	`stats` text,
	`fts_rowid` integer,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`deleted_at` integer, `compaction_summary` text,
	FOREIGN KEY (`topic_id`) REFERENCES `topic`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`model_id`) REFERENCES `user_model`(`id`) ON UPDATE no action ON DELETE set null,
	FOREIGN KEY (`parent_id`) REFERENCES `message`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "message_role_check" CHECK("message"."role" IN ('user', 'assistant', 'system', 'root')),
	CONSTRAINT "message_status_check" CHECK("message"."status" IN ('pending', 'success', 'error', 'paused')),
	CONSTRAINT "message_root_parent_check" CHECK(("message"."role" = 'root') = ("message"."parent_id" is null))
);
CREATE TABLE `note` (
	`id` text PRIMARY KEY NOT NULL,
	`root_path` text NOT NULL,
	`path` text NOT NULL,
	`is_starred` integer DEFAULT false NOT NULL,
	`is_expanded` integer DEFAULT false NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	CONSTRAINT "note_has_state_check" CHECK("note"."is_starred" = 1 OR "note"."is_expanded" = 1)
);
CREATE TABLE `painting` (
	`id` text PRIMARY KEY NOT NULL,
	`provider_id` text NOT NULL,
	`model_id` text,
	`prompt` text NOT NULL,
	`order_key` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
, `deleted_at` integer);
CREATE TABLE `pin` (
	`id` text PRIMARY KEY NOT NULL,
	`entity_type` text NOT NULL,
	`entity_id` text NOT NULL,
	`order_key` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
CREATE TABLE `preference` (
	`scope` text DEFAULT 'default' NOT NULL,
	`key` text NOT NULL,
	`value` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`scope`, `key`)
);
CREATE TABLE `entity_tag` (
	`entity_type` text NOT NULL,
	`entity_id` text NOT NULL,
	`tag_id` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`entity_type`, `entity_id`, `tag_id`),
	FOREIGN KEY (`tag_id`) REFERENCES `tag`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE `tag` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`color` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
CREATE TABLE `translate_history` (
	`id` text PRIMARY KEY NOT NULL,
	`source_text` text NOT NULL,
	`target_text` text NOT NULL,
	`source_language` text,
	`target_language` text,
	`star` integer DEFAULT false NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL, `kind` text DEFAULT 'text' NOT NULL,
	FOREIGN KEY (`source_language`) REFERENCES `translate_language`(`lang_code`) ON UPDATE no action ON DELETE set null,
	FOREIGN KEY (`target_language`) REFERENCES `translate_language`(`lang_code`) ON UPDATE no action ON DELETE set null
);
CREATE TABLE `translate_language` (
	`lang_code` text PRIMARY KEY NOT NULL,
	`value` text NOT NULL,
	`emoji` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
CREATE TABLE `user_model` (
	`id` text PRIMARY KEY NOT NULL,
	`provider_id` text NOT NULL,
	`model_id` text NOT NULL,
	`preset_model_id` text,
	`name` text,
	`description` text,
	`group` text,
	`capabilities` text,
	`input_modalities` text,
	`output_modalities` text,
	`endpoint_types` text,
	`context_window` integer,
	`max_input_tokens` integer,
	`max_output_tokens` integer,
	`supports_streaming` integer,
	`reasoning` text,
	`parameters` text,
	`pricing` text,
	`is_enabled` integer DEFAULT true NOT NULL,
	`is_hidden` integer DEFAULT false NOT NULL,
	`is_deprecated` integer DEFAULT false NOT NULL,
	`order_key` text NOT NULL,
	`notes` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL, `input_modalities_explicit` integer DEFAULT false NOT NULL,
	FOREIGN KEY (`provider_id`) REFERENCES `user_provider`(`provider_id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "user_model_custom_config_check" CHECK("user_model"."preset_model_id" IS NOT NULL OR ("user_model"."name" IS NOT NULL AND "user_model"."capabilities" IS NOT NULL AND "user_model"."supports_streaming" IS NOT NULL))
);
CREATE TABLE `user_provider` (
	`provider_id` text PRIMARY KEY NOT NULL,
	`preset_provider_id` text,
	`name` text NOT NULL,
	`logo_key` text,
	`endpoint_configs` text,
	`default_chat_endpoint` text,
	`api_keys` text DEFAULT '[]',
	`auth_config` text,
	`provider_settings` text,
	`is_enabled` integer DEFAULT false NOT NULL,
	`order_key` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
CREATE TABLE "agent_channel" (
	`id` text PRIMARY KEY NOT NULL,
	`type` text NOT NULL,
	`name` text NOT NULL,
	`agent_id` text,
	`session_id` text,
	`workspace` text NOT NULL,
	`config` text NOT NULL,
	`is_active` integer DEFAULT true NOT NULL,
	`active_chat_ids` text DEFAULT '[]' NOT NULL,
	`permission_mode` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`agent_id`) REFERENCES `agent`(`id`) ON UPDATE no action ON DELETE set null,
	FOREIGN KEY (`session_id`) REFERENCES `agent_session`(`id`) ON UPDATE no action ON DELETE set null
);
CREATE TABLE `job_file_ref` (
	`id` text PRIMARY KEY NOT NULL,
	`file_entry_id` text NOT NULL,
	`source_id` text NOT NULL,
	`role` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`file_entry_id`) REFERENCES `file_entry`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`source_id`) REFERENCES `job`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "jfr_role_check" CHECK("job_file_ref"."role" IN ('input', 'mask'))
);
CREATE TABLE "file_entry" (
	`id` text PRIMARY KEY NOT NULL,
	`origin` text NOT NULL,
	`name` text NOT NULL,
	`ext` text,
	`size` integer,
	`content_hash` text,
	`external_path` text,
	`cleanup_policy` text DEFAULT 'manual' NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`deleted_at` integer,
	CONSTRAINT "fe_origin_check" CHECK("file_entry"."origin" IN ('internal', 'external')),
	CONSTRAINT "fe_cleanup_policy_check" CHECK("file_entry"."cleanup_policy" IN ('manual', 'delete_when_unreferenced')),
	CONSTRAINT "fe_origin_consistency" CHECK(("file_entry"."origin" = 'internal' AND "file_entry"."external_path" IS NULL) OR ("file_entry"."origin" = 'external' AND "file_entry"."external_path" IS NOT NULL)),
	CONSTRAINT "fe_external_no_delete" CHECK("file_entry"."origin" != 'external' OR "file_entry"."deleted_at" IS NULL),
	CONSTRAINT "fe_contenthash_external_null" CHECK("file_entry"."origin" != 'external' OR "file_entry"."content_hash" IS NULL),
	CONSTRAINT "fe_size_internal_only" CHECK(("file_entry"."origin" = 'internal' AND "file_entry"."size" IS NOT NULL AND "file_entry"."size" >= 0) OR ("file_entry"."origin" = 'external' AND "file_entry"."size" IS NULL))
);
CREATE TABLE "topic" (
	`id` text PRIMARY KEY NOT NULL,
	`name` text DEFAULT '' NOT NULL,
	`is_name_manually_edited` integer DEFAULT false NOT NULL,
	`assistant_id` text,
	`active_node_id` text,
	`trace_id` text,
	`order_key` text NOT NULL,
	`last_activity_at` integer NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`deleted_at` integer,
	FOREIGN KEY (`assistant_id`) REFERENCES `assistant`(`id`) ON UPDATE no action ON DELETE set null
);
CREATE TABLE `translate_history_file_ref` (
	`id` text PRIMARY KEY NOT NULL,
	`file_entry_id` text NOT NULL,
	`source_id` text NOT NULL,
	`role` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`file_entry_id`) REFERENCES `file_entry`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`source_id`) REFERENCES `translate_history`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "thfr_role_check" CHECK("translate_history_file_ref"."role" IN ('source', 'target'))
);
CREATE TABLE `agent_channel_session` (
	`session_id` text PRIMARY KEY NOT NULL,
	`channel_id` text NOT NULL,
	`conversation_id` text,
	`is_active` integer DEFAULT false NOT NULL,
	FOREIGN KEY (`session_id`) REFERENCES `agent_session`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`channel_id`) REFERENCES `agent_channel`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "agent_channel_session_conversation_id_nonempty_check" CHECK("agent_channel_session"."conversation_id" IS NULL OR length(trim("agent_channel_session"."conversation_id")) > 0),
	CONSTRAINT "agent_channel_session_active_conversation_check" CHECK("agent_channel_session"."is_active" = 0 OR "agent_channel_session"."conversation_id" IS NOT NULL)
);
CREATE TABLE "mcp_server" (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`type` text,
	`description` text,
	`base_url` text,
	`command` text,
	`registry_url` text,
	`args` text,
	`env` text,
	`headers` text,
	`provider` text,
	`provider_url` text,
	`logo_url` text,
	`tags` text,
	`long_running` integer,
	`timeout` integer,
	`dxt_version` text,
	`dxt_path` text,
	`reference` text,
	`search_key` text,
	`config_sample` text,
	`disabled_tools` text,
	`disabled_auto_approve_tools` text,
	`should_config` integer,
	`sort_order` integer DEFAULT 0,
	`is_active` integer DEFAULT false NOT NULL,
	`install_source` text,
	`is_trusted` integer,
	`trusted_at` integer,
	`installed_at` integer,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	CONSTRAINT "mcp_server_type_check" CHECK("mcp_server"."type" IS NULL OR "mcp_server"."type" IN ('stdio', 'sse', 'streamableHttp', 'inMemory')),
	CONSTRAINT "mcp_server_install_source_check" CHECK("mcp_server"."install_source" IS NULL OR "mcp_server"."install_source" IN ('builtin', 'manual', 'ai_assisted', 'protocol', 'unknown'))
);
CREATE TABLE `prompt_binding` (
	`prompt_id` text NOT NULL,
	`target_type` text NOT NULL,
	`target_id` text NOT NULL,
	`order_key` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`prompt_id`, `target_type`, `target_id`),
	FOREIGN KEY (`prompt_id`) REFERENCES `prompt`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "prompt_binding_target_type_check" CHECK("prompt_binding"."target_type" IN ('assistant', 'agent'))
);
CREATE TABLE "prompt" (
	`id` text PRIMARY KEY NOT NULL,
	`title` text NOT NULL,
	`content` text NOT NULL,
	`visibility` text NOT NULL,
	`order_key` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	CONSTRAINT "prompt_visibility_check" CHECK("prompt"."visibility" IN ('global', 'restricted'))
);
CREATE VIRTUAL TABLE `agent_session_message_fts` USING fts5(
  searchable_text,
  content='agent_session_message',
  content_rowid='fts_rowid',
  tokenize='trigram'
);
CREATE TABLE `mini_app_file_ref` (
	`id` text PRIMARY KEY NOT NULL,
	`file_entry_id` text NOT NULL,
	`source_id` text NOT NULL,
	`logical_name` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`file_entry_id`) REFERENCES `file_entry`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`source_id`) REFERENCES `mini_app`(`app_id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE `mini_app_grant` (
	`id` text PRIMARY KEY NOT NULL,
	`app_id` text NOT NULL,
	`permission` text NOT NULL,
	`granted_version` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`app_id`) REFERENCES `mini_app`(`app_id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE `mini_app_installation` (
	`app_id` text PRIMARY KEY NOT NULL,
	`version` text NOT NULL,
	`content_hash` text NOT NULL,
	`source` text NOT NULL,
	`source_url` text,
	`source_origin` text,
	`source_origin_cn` text,
	`manifest_json` text NOT NULL,
	`previous_manifest_json` text,
	`previous_content_hash` text,
	`previous_grants_json` text,
	`previous_consented_declared_json` text,
	`consented_declared_json` text DEFAULT '[]' NOT NULL,
	`ai_model_id` text,
	`ai_quick_model_id` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`app_id`) REFERENCES `mini_app`(`app_id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "mai_source_check" CHECK("mini_app_installation"."source" IN ('file', 'url', 'builtin')),
	CONSTRAINT "mai_rollback_snapshot_all_or_none" CHECK(("mini_app_installation"."previous_content_hash" IS NULL AND "mini_app_installation"."previous_manifest_json" IS NULL
           AND "mini_app_installation"."previous_grants_json" IS NULL AND "mini_app_installation"."previous_consented_declared_json" IS NULL)
          OR ("mini_app_installation"."previous_content_hash" IS NOT NULL AND "mini_app_installation"."previous_manifest_json" IS NOT NULL
              AND "mini_app_installation"."previous_grants_json" IS NOT NULL AND "mini_app_installation"."previous_consented_declared_json" IS NOT NULL)),
	CONSTRAINT "mai_source_consistency" CHECK(("mini_app_installation"."source" IN ('file', 'builtin') AND "mini_app_installation"."source_url" IS NULL AND "mini_app_installation"."source_origin" IS NULL
           AND "mini_app_installation"."source_origin_cn" IS NULL)
          OR ("mini_app_installation"."source" = 'url' AND "mini_app_installation"."source_url" IS NOT NULL AND "mini_app_installation"."source_origin" IS NOT NULL))
);
CREATE TABLE "ai_usage_record" (
	`id` text PRIMARY KEY NOT NULL,
	`request_id` text NOT NULL,
	`record_kind` text NOT NULL,
	`request_count` integer NOT NULL,
	`message_kind` text,
	`message_id` text,
	`provider_id` text,
	`provider_name` text,
	`model_id` text,
	`model_name` text,
	`source_type` text,
	`source_id` text,
	`source_name` text,
	`source_icon` text,
	`modality` text NOT NULL,
	`api_key_id` text,
	`api_key_label` text,
	`api_key_masked` text,
	`api_key_attribution` text NOT NULL,
	`auth_method` text,
	`input_tokens` integer,
	`output_tokens` integer,
	`total_tokens` integer,
	`reasoning_tokens` integer,
	`no_cache_tokens` integer,
	`cache_read_tokens` integer,
	`cache_write_tokens` integer,
	`image_count` integer,
	`cost` real,
	`cost_currency` text,
	`cost_source` text,
	`cost_breakdown` text,
	`pricing_snapshot` text,
	`time_first_token_ms` integer,
	`time_completion_ms` integer,
	`time_thinking_ms` integer,
	`created_at` integer NOT NULL,
	CONSTRAINT "ai_usage_record_record_kind_check" CHECK("ai_usage_record"."record_kind" IN ('invocation', 'legacy-aggregate')),
	CONSTRAINT "ai_usage_record_message_kind_check" CHECK("ai_usage_record"."message_kind" IN ('chat', 'agent-session')),
	CONSTRAINT "ai_usage_record_source_type_check" CHECK("ai_usage_record"."source_type" IN ('assistant', 'agent', 'mini-app')),
	CONSTRAINT "ai_usage_record_modality_check" CHECK("ai_usage_record"."modality" IN ('language', 'embedding', 'image', 'rerank')),
	CONSTRAINT "ai_usage_record_attribution_check" CHECK("ai_usage_record"."api_key_attribution" IN ('explicit', 'matched', 'auth', 'unknown')),
	CONSTRAINT "ai_usage_record_auth_method_check" CHECK("ai_usage_record"."auth_method" IN ('oauth', 'external-cli', 'iam-aws', 'api-key-aws', 'iam-gcp', 'iam-azure')),
	CONSTRAINT "ai_usage_record_cost_source_check" CHECK("ai_usage_record"."cost_source" IN ('provider', 'computed')),
	CONSTRAINT "ai_usage_record_cost_currency_check" CHECK("ai_usage_record"."cost_currency" IN ('USD', 'CNY')),
	CONSTRAINT "ai_usage_record_kind_identity_check" CHECK((
        "ai_usage_record"."record_kind" = 'invocation'
        AND "ai_usage_record"."request_count" = 1
        AND "ai_usage_record"."provider_id" IS NOT NULL
        AND "ai_usage_record"."model_id" IS NOT NULL
      ) OR (
        "ai_usage_record"."record_kind" = 'legacy-aggregate'
        AND "ai_usage_record"."request_count" >= 1
        AND "ai_usage_record"."message_kind" IS NOT NULL
        AND "ai_usage_record"."message_id" IS NOT NULL
      )),
	CONSTRAINT "ai_usage_record_message_identity_check" CHECK(("ai_usage_record"."message_kind" IS NULL AND "ai_usage_record"."message_id" IS NULL)
        OR ("ai_usage_record"."message_kind" IS NOT NULL AND "ai_usage_record"."message_id" IS NOT NULL)),
	CONSTRAINT "ai_usage_record_source_identity_check" CHECK((
        "ai_usage_record"."source_type" IS NULL
        AND "ai_usage_record"."source_id" IS NULL
        AND "ai_usage_record"."source_name" IS NULL
        AND "ai_usage_record"."source_icon" IS NULL
      ) OR (
        "ai_usage_record"."source_type" IS NOT NULL
        AND "ai_usage_record"."source_id" IS NOT NULL
      )),
	CONSTRAINT "ai_usage_record_api_key_identity_check" CHECK((
        "ai_usage_record"."api_key_attribution" IN ('explicit', 'matched')
        AND "ai_usage_record"."api_key_id" IS NOT NULL
        AND "ai_usage_record"."auth_method" IS NULL
      ) OR (
        "ai_usage_record"."api_key_attribution" = 'auth'
        AND "ai_usage_record"."api_key_id" IS NULL
        AND "ai_usage_record"."api_key_label" IS NULL
        AND "ai_usage_record"."api_key_masked" IS NULL
        AND "ai_usage_record"."auth_method" IS NOT NULL
      ) OR (
        "ai_usage_record"."api_key_attribution" = 'unknown'
        AND "ai_usage_record"."api_key_id" IS NULL
        AND "ai_usage_record"."api_key_label" IS NULL
        AND "ai_usage_record"."api_key_masked" IS NULL
        AND "ai_usage_record"."auth_method" IS NULL
      )),
	CONSTRAINT "ai_usage_record_cost_tuple_check" CHECK((
        "ai_usage_record"."cost" IS NULL
        AND "ai_usage_record"."cost_currency" IS NULL
        AND "ai_usage_record"."cost_source" IS NULL
        AND "ai_usage_record"."cost_breakdown" IS NULL
      ) OR (
        "ai_usage_record"."cost" IS NOT NULL
        AND "ai_usage_record"."cost_currency" IS NOT NULL
        AND "ai_usage_record"."cost_source" IS NOT NULL
      )),
	CONSTRAINT "ai_usage_record_image_count_check" CHECK((
        "ai_usage_record"."modality" = 'image'
        AND "ai_usage_record"."image_count" IS NOT NULL
        AND "ai_usage_record"."image_count" >= 0
      ) OR (
        "ai_usage_record"."modality" <> 'image'
        AND "ai_usage_record"."image_count" IS NULL
      )),
	CONSTRAINT "ai_usage_record_nonnegative_check" CHECK(
        ("ai_usage_record"."input_tokens" IS NULL OR "ai_usage_record"."input_tokens" >= 0)
        AND ("ai_usage_record"."output_tokens" IS NULL OR "ai_usage_record"."output_tokens" >= 0)
        AND ("ai_usage_record"."total_tokens" IS NULL OR "ai_usage_record"."total_tokens" >= 0)
        AND ("ai_usage_record"."reasoning_tokens" IS NULL OR "ai_usage_record"."reasoning_tokens" >= 0)
        AND ("ai_usage_record"."no_cache_tokens" IS NULL OR "ai_usage_record"."no_cache_tokens" >= 0)
        AND ("ai_usage_record"."cache_read_tokens" IS NULL OR "ai_usage_record"."cache_read_tokens" >= 0)
        AND ("ai_usage_record"."cache_write_tokens" IS NULL OR "ai_usage_record"."cache_write_tokens" >= 0)
        AND ("ai_usage_record"."cost" IS NULL OR "ai_usage_record"."cost" >= 0)
        AND ("ai_usage_record"."time_first_token_ms" IS NULL OR "ai_usage_record"."time_first_token_ms" >= 0)
        AND ("ai_usage_record"."time_completion_ms" IS NULL OR "ai_usage_record"."time_completion_ms" >= 0)
        AND ("ai_usage_record"."time_thinking_ms" IS NULL OR "ai_usage_record"."time_thinking_ms" >= 0)
      ),
	CONSTRAINT "ai_usage_record_integer_check" CHECK(
        typeof("ai_usage_record"."request_count") = 'integer'
        AND ("ai_usage_record"."input_tokens" IS NULL OR typeof("ai_usage_record"."input_tokens") = 'integer')
        AND ("ai_usage_record"."output_tokens" IS NULL OR typeof("ai_usage_record"."output_tokens") = 'integer')
        AND ("ai_usage_record"."total_tokens" IS NULL OR typeof("ai_usage_record"."total_tokens") = 'integer')
        AND ("ai_usage_record"."reasoning_tokens" IS NULL OR typeof("ai_usage_record"."reasoning_tokens") = 'integer')
        AND ("ai_usage_record"."no_cache_tokens" IS NULL OR typeof("ai_usage_record"."no_cache_tokens") = 'integer')
        AND ("ai_usage_record"."cache_read_tokens" IS NULL OR typeof("ai_usage_record"."cache_read_tokens") = 'integer')
        AND ("ai_usage_record"."cache_write_tokens" IS NULL OR typeof("ai_usage_record"."cache_write_tokens") = 'integer')
        AND ("ai_usage_record"."image_count" IS NULL OR typeof("ai_usage_record"."image_count") = 'integer')
        AND ("ai_usage_record"."time_first_token_ms" IS NULL OR typeof("ai_usage_record"."time_first_token_ms") = 'integer')
        AND ("ai_usage_record"."time_completion_ms" IS NULL OR typeof("ai_usage_record"."time_completion_ms") = 'integer')
        AND ("ai_usage_record"."time_thinking_ms" IS NULL OR typeof("ai_usage_record"."time_thinking_ms") = 'integer')
        AND typeof("ai_usage_record"."created_at") = 'integer'
      ),
	CONSTRAINT "ai_usage_record_finite_cost_check" CHECK("ai_usage_record"."cost" IS NULL OR "ai_usage_record"."cost" <= 1.7976931348623157e308)
);
CREATE TABLE "mini_app" (
	`app_id` text PRIMARY KEY NOT NULL,
	`preset_mini_app_id` text,
	`kind` text DEFAULT 'site' NOT NULL,
	`name` text NOT NULL,
	`url` text NOT NULL,
	`logo_key` text,
	`status` text DEFAULT 'enabled' NOT NULL,
	`order_key` text NOT NULL,
	`bordered` integer DEFAULT true NOT NULL,
	`background` text,
	`supported_regions` text,
	`configuration` text,
	`name_key` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	CONSTRAINT "mini_app_status_check" CHECK("mini_app"."status" IN ('enabled', 'disabled', 'pinned')),
	CONSTRAINT "mini_app_kind_check" CHECK("mini_app"."kind" IN ('site', 'app'))
);
CREATE TABLE `api_gateway_paired_device` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`platform` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
, `peer_identity` text, `configuration_grant_id` text, `agent_grant_id` text);
CREATE TABLE `browser_visit` (
	`id` text PRIMARY KEY NOT NULL,
	`url` text NOT NULL,
	`title` text NOT NULL,
	`visited_at` integer NOT NULL,
	`source` text DEFAULT 'local' NOT NULL,
	`source_key` text
);
CREATE TABLE `remote_command` (
	`device_id` text NOT NULL,
	`grant_id` text NOT NULL,
	`command_id` text NOT NULL,
	`method` text NOT NULL,
	`identity_digest` text NOT NULL,
	`status` text NOT NULL,
	`session_id` text,
	`execution_id` text,
	`result` text,
	`error` text,
	`admitted_at` integer NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`device_id`, `grant_id`, `command_id`),
	FOREIGN KEY (`device_id`) REFERENCES `api_gateway_paired_device`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE `diagnostic_report` (
	`report_id` text PRIMARY KEY NOT NULL,
	`submitted_at` integer NOT NULL,
	`processing_status` text,
	`last_checked_at` integer,
	CONSTRAINT "diagnostic_report_processing_status_check" CHECK("diagnostic_report"."processing_status" IN ('pending', 'unprocessed', 'investigating', 'resolved', 'closed'))
);
CREATE TABLE "knowledge_base" (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`order_key` text NOT NULL,
	`group_id` text,
	`dimensions` integer,
	`embedding_model_id` text,
	`status` text NOT NULL,
	`error` text,
	`rerank_model_id` text,
	`file_processor_id` text,
	`chunk_size` integer NOT NULL,
	`chunk_overlap` integer NOT NULL,
	`chunk_strategy` text DEFAULT 'structured' NOT NULL,
	`chunk_separator` text DEFAULT '\n\n' NOT NULL,
	`threshold` real,
	`document_count` integer,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`group_id`) REFERENCES `group`(`id`) ON UPDATE no action ON DELETE set null,
	FOREIGN KEY (`embedding_model_id`) REFERENCES `user_model`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`rerank_model_id`) REFERENCES `user_model`(`id`) ON UPDATE no action ON DELETE set null,
	CONSTRAINT "knowledge_base_chunk_strategy_check" CHECK("knowledge_base"."chunk_strategy" IN ('structured', 'delimiter')),
	CONSTRAINT "knowledge_base_status_check" CHECK("knowledge_base"."status" IN ('completed', 'failed')),
	CONSTRAINT "knowledge_base_status_error_check" CHECK(
        (
          "knowledge_base"."status" = 'completed'
          AND "knowledge_base"."error" IS NULL
          AND (
            (
              "knowledge_base"."embedding_model_id" IS NOT NULL
              AND "knowledge_base"."dimensions" IS NOT NULL
              AND "knowledge_base"."dimensions" > 0
            )
            OR (
              "knowledge_base"."embedding_model_id" IS NULL
              AND "knowledge_base"."dimensions" IS NULL
            )
          )
        )
        OR (
          "knowledge_base"."status" = 'failed'
          AND "knowledge_base"."error" IS NOT NULL
          AND length(trim("knowledge_base"."error")) > 0
        )
      )
);
CREATE TABLE "knowledge_item" (
	`id` text PRIMARY KEY NOT NULL,
	`base_id` text NOT NULL,
	`group_id` text,
	`type` text NOT NULL,
	`data` text NOT NULL,
	`status` text NOT NULL,
	`error` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`base_id`) REFERENCES `knowledge_base`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`base_id`,`group_id`) REFERENCES `knowledge_item`(`base_id`,`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "knowledge_item_type_check" CHECK("knowledge_item"."type" IN ('file', 'url', 'note', 'directory')),
	CONSTRAINT "knowledge_item_status_check" CHECK("knowledge_item"."status" IN ('idle', 'preparing', 'processing', 'reading', 'embedding', 'completed', 'failed', 'deleting')),
	CONSTRAINT "knowledge_item_type_status_check" CHECK(
        ("knowledge_item"."type" IN ('url', 'note') AND "knowledge_item"."status" IN ('idle', 'processing', 'reading', 'embedding', 'completed', 'failed', 'deleting'))
        OR ("knowledge_item"."type" = 'file' AND "knowledge_item"."status" IN ('idle', 'preparing', 'processing', 'reading', 'embedding', 'completed', 'failed', 'deleting'))
        OR ("knowledge_item"."type" = 'directory' AND "knowledge_item"."status" IN ('idle', 'preparing', 'processing', 'completed', 'failed', 'deleting'))
      ),
	CONSTRAINT "knowledge_item_status_error_check" CHECK(
        (
          "knowledge_item"."status" IN ('idle', 'preparing', 'processing', 'reading', 'embedding', 'completed', 'deleting')
          AND "knowledge_item"."error" IS NULL
        )
        OR (
          "knowledge_item"."status" = 'failed'
          AND "knowledge_item"."error" IS NOT NULL
          AND length(trim("knowledge_item"."error")) > 0
        )
      )
);
CREATE TABLE `agent_runtime_backend` (
	`id` text PRIMARY KEY NOT NULL,
	`locator` text NOT NULL,
	`state` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	CONSTRAINT "agent_runtime_backend_state_check" CHECK("agent_runtime_backend"."state" IN ('creating', 'bound'))
);
CREATE TABLE `agent_session_context` (
	`id` text PRIMARY KEY NOT NULL,
	`session_id` text NOT NULL,
	`backend_id` text NOT NULL,
	`native_thread_id` text,
	`binding_state` text DEFAULT 'pending' NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL, `anchor_message_id` text, `checkpoint_mapping` text, `parent_context_id` text REFERENCES agent_session_context(id) ON DELETE CASCADE, `spawn_tool_call_id` text,
	FOREIGN KEY (`session_id`) REFERENCES `agent_session`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`backend_id`) REFERENCES `agent_runtime_backend`(`id`) ON UPDATE no action ON DELETE restrict,
	CONSTRAINT "agent_session_context_binding_state_check" CHECK("agent_session_context"."binding_state" IN ('pending', 'bound')),
	CONSTRAINT "agent_session_context_bound_identity_check" CHECK("agent_session_context"."binding_state" != 'bound' OR "agent_session_context"."native_thread_id" IS NOT NULL)
);
CREATE TABLE `notification_record` (
	`id` text PRIMARY KEY NOT NULL,
	`event_key` text NOT NULL,
	`category` text NOT NULL,
	`kind` text NOT NULL,
	`title` text NOT NULL,
	`message` text NOT NULL,
	`created_at` integer NOT NULL,
	`read_at` integer,
	`dismissed_at` integer,
	`target` text
);
CREATE TABLE "agent_session" (
	`id` text PRIMARY KEY NOT NULL,
	`owner_session_id` text,
	`type` text DEFAULT 'conversation' NOT NULL,
	`agent_id` text,
	`name` text NOT NULL,
	`is_name_manually_edited` integer DEFAULT false NOT NULL,
	`description` text DEFAULT '' NOT NULL,
	`workspace_id` text NOT NULL,
	`task_id` text,
	`is_task_reuse_target` integer DEFAULT false NOT NULL,
	`trace_id` text,
	`active_node_id` text,
	`order_key` text NOT NULL,
	`last_activity_at` integer NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`deleted_at` integer, `model` text REFERENCES user_model(id) ON DELETE SET NULL,
	FOREIGN KEY (`owner_session_id`) REFERENCES `agent_session`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`agent_id`) REFERENCES `agent`(`id`) ON UPDATE no action ON DELETE set null,
	FOREIGN KEY (`workspace_id`) REFERENCES `agent_workspace`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`task_id`) REFERENCES `job_schedule`(`id`) ON UPDATE no action ON DELETE set null,
	CONSTRAINT "agent_session_task_reuse_owner_check" CHECK("agent_session"."is_task_reuse_target" = 0 OR "agent_session"."task_id" IS NOT NULL)
);
CREATE TABLE `assistant_avatar_file_ref` (
	`id` text PRIMARY KEY NOT NULL,
	`file_entry_id` text NOT NULL,
	`source_id` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`file_entry_id`) REFERENCES `file_entry`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`source_id`) REFERENCES `assistant`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE "chat_message_file_ref" (
	`id` text PRIMARY KEY NOT NULL,
	`file_entry_id` text NOT NULL,
	`source_id` text NOT NULL,
	`role` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`file_entry_id`) REFERENCES `file_entry`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`source_id`) REFERENCES `message`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "cmfr_role_check" CHECK("chat_message_file_ref"."role" IN ('attachment', 'tool_output', 'author_avatar'))
);
CREATE TABLE `agent_avatar_file_ref` (
	`id` text PRIMARY KEY NOT NULL,
	`file_entry_id` text NOT NULL,
	`source_id` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`file_entry_id`) REFERENCES `file_entry`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`source_id`) REFERENCES `agent`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE TABLE "agent_session_message_file_ref" (
	`id` text PRIMARY KEY NOT NULL,
	`file_entry_id` text NOT NULL,
	`source_id` text NOT NULL,
	`role` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`file_entry_id`) REFERENCES `file_entry`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`source_id`) REFERENCES `agent_session_message`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "asmfr_role_check" CHECK("agent_session_message_file_ref"."role" IN ('attachment', 'author_avatar'))
);
CREATE TABLE "agent_session_message" (
	`id` text PRIMARY KEY NOT NULL,
	`session_id` text NOT NULL,
	`role` text NOT NULL,
	`parent_id` text,
	`data` text NOT NULL,
	`searchable_text` text DEFAULT '' NOT NULL,
	`status` text NOT NULL,
	`model_id` text,
	`message_snapshot` text,
	`stats` text,
	`runtime_resume_token` text,
	`input_context_id` text,
	`native_input_id` text,
	`delivery` text,
	`delivery_status` text,
	`delivery_turn_ref` text,
	`delivery_in_reply_to` text,
	`delivery_sender_session_id` text,
	`fts_rowid` integer,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL, `reply_id` text,
	FOREIGN KEY (`session_id`) REFERENCES `agent_session`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`model_id`) REFERENCES `user_model`(`id`) ON UPDATE no action ON DELETE set null,
	FOREIGN KEY (`input_context_id`) REFERENCES `agent_session_context`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`session_id`,`parent_id`) REFERENCES `agent_session_message`(`session_id`,`id`) ON UPDATE no action ON DELETE no action,
	CONSTRAINT "agent_session_message_root_parent_check" CHECK(("agent_session_message"."role" = 'root') = ("agent_session_message"."parent_id" IS NULL)),
	CONSTRAINT "agent_session_message_role_check" CHECK("agent_session_message"."role" IN ('root', 'user', 'assistant', 'system')),
	CONSTRAINT "agent_session_message_status_check" CHECK("agent_session_message"."status" IN ('pending', 'success', 'error', 'paused')),
	CONSTRAINT "agent_session_message_delivery_status_check" CHECK("agent_session_message"."delivery_status" IS NULL OR "agent_session_message"."delivery_status" IN ('accepted', 'delivering', 'consumed', 'failed')),
	CONSTRAINT "agent_session_message_delivery_turn_ref_check" CHECK(("agent_session_message"."delivery_status" = 'delivering' AND "agent_session_message"."delivery_turn_ref" IS NOT NULL) OR ("agent_session_message"."delivery_status" != 'delivering' AND "agent_session_message"."delivery_turn_ref" IS NULL) OR ("agent_session_message"."delivery_status" IS NULL AND "agent_session_message"."delivery_turn_ref" IS NULL))
);
CREATE INDEX `agent_name_idx` ON `agent` (`name`);
CREATE INDEX `agent_type_idx` ON `agent` (`type`);
CREATE INDEX `agent_order_key_idx` ON `agent` (`order_key`);
CREATE INDEX `agent_channel_task_channel_id_idx` ON `agent_channel_task` (`channel_id`);
CREATE INDEX `agent_channel_task_task_id_idx` ON `agent_channel_task` (`task_id`);
CREATE UNIQUE INDEX `agent_global_skill_folder_name_unique` ON `agent_global_skill` (`folder_name`);
CREATE INDEX `agent_global_skill_source_idx` ON `agent_global_skill` (`source`);
CREATE INDEX `agent_global_skill_is_enabled_idx` ON `agent_global_skill` (`is_enabled`);
CREATE INDEX `agent_skill_agent_id_idx` ON `agent_skill` (`agent_id`);
CREATE INDEX `agent_skill_skill_id_idx` ON `agent_skill` (`skill_id`);
CREATE UNIQUE INDEX `agent_workspace_path_unique_idx` ON `agent_workspace` (`path`);
CREATE INDEX `agent_workspace_order_key_idx` ON `agent_workspace` (`order_key`);
CREATE INDEX `assistant_created_at_idx` ON `assistant` (`created_at`);
CREATE INDEX `assistant_order_key_idx` ON `assistant` (`order_key`);
CREATE INDEX `malfr_entry_id_idx` ON `mini_app_logo_file_ref` (`file_entry_id`);
CREATE UNIQUE INDEX `malfr_source_id_idx` ON `mini_app_logo_file_ref` (`source_id`);
CREATE INDEX `pfr_entry_id_idx` ON `painting_file_ref` (`file_entry_id`);
CREATE INDEX `pfr_source_id_idx` ON `painting_file_ref` (`source_id`);
CREATE UNIQUE INDEX `pfr_unique_idx` ON `painting_file_ref` (`file_entry_id`,`source_id`,`role`);
CREATE INDEX `plfr_entry_id_idx` ON `provider_logo_file_ref` (`file_entry_id`);
CREATE UNIQUE INDEX `plfr_source_id_idx` ON `provider_logo_file_ref` (`source_id`);
CREATE INDEX `group_entity_type_order_key_idx` ON `group` (`entity_type`,`order_key`);
CREATE UNIQUE INDEX `job_schedule_type_name_uq` ON `job_schedule` (`type`,`name`);
CREATE INDEX `job_schedule_enabled_next_run_idx` ON `job_schedule` (`enabled`,`next_run`);
CREATE INDEX `job_schedule_type_idx` ON `job_schedule` (`type`);
CREATE INDEX `job_queue_status_scheduled_at_idx` ON `job` (`queue`,`status`,`scheduled_at`);
CREATE INDEX `job_status_idx` ON `job` (`status`);
CREATE INDEX `job_schedule_id_finished_at_idx` ON `job` (`schedule_id`,`finished_at`);
CREATE INDEX `job_parent_id_idx` ON `job` (`parent_id`);
CREATE UNIQUE INDEX `job_idempotency_key_partial_uq` ON `job` (`idempotency_key`) WHERE "job"."idempotency_key" IS NOT NULL AND "job"."status" NOT IN ('completed','failed','cancelled');
CREATE INDEX `message_parent_id_idx` ON `message` (`parent_id`);
CREATE INDEX `message_topic_created_idx` ON `message` (`topic_id`,`created_at`);
CREATE INDEX `message_status_idx` ON `message` (`status`);
CREATE UNIQUE INDEX `message_topic_root_uniq` ON `message` (`topic_id`) WHERE "message"."parent_id" is null and "message"."deleted_at" is null;
CREATE UNIQUE INDEX `message_fts_rowid_uniq` ON `message` (`fts_rowid`);
CREATE UNIQUE INDEX `note_root_path_path_unique_idx` ON `note` (`root_path`,`path`);
CREATE INDEX `painting_order_key_idx` ON `painting` (`order_key`);
CREATE UNIQUE INDEX `pin_entity_type_entity_id_unique_idx` ON `pin` (`entity_type`,`entity_id`);
CREATE INDEX `pin_entity_type_order_key_idx` ON `pin` (`entity_type`,`order_key`);
CREATE INDEX `entity_tag_tag_id_idx` ON `entity_tag` (`tag_id`);
CREATE UNIQUE INDEX `tag_name_unique` ON `tag` (`name`);
CREATE INDEX `translate_history_created_at_idx` ON `translate_history` (`created_at`);
CREATE INDEX `translate_history_star_created_at_idx` ON `translate_history` (`star`,`created_at`);
CREATE INDEX `user_model_preset_idx` ON `user_model` (`preset_model_id`);
CREATE INDEX `user_model_provider_enabled_idx` ON `user_model` (`provider_id`,`is_enabled`);
CREATE INDEX `user_model_provider_id_order_key_idx` ON `user_model` (`provider_id`,`order_key`);
CREATE UNIQUE INDEX `user_model_provider_model_unique` ON `user_model` (`provider_id`,`model_id`);
CREATE INDEX `user_provider_preset_idx` ON `user_provider` (`preset_provider_id`);
CREATE INDEX `user_provider_enabled_idx` ON `user_provider` (`is_enabled`);
CREATE INDEX `user_provider_order_key_idx` ON `user_provider` (`order_key`);
CREATE INDEX `agent_channel_agent_id_idx` ON `agent_channel` (`agent_id`);
CREATE INDEX `agent_channel_type_idx` ON `agent_channel` (`type`);
CREATE INDEX `agent_channel_session_id_idx` ON `agent_channel` (`session_id`);
CREATE INDEX `jfr_entry_id_idx` ON `job_file_ref` (`file_entry_id`);
CREATE INDEX `jfr_source_id_idx` ON `job_file_ref` (`source_id`);
CREATE UNIQUE INDEX `jfr_unique_idx` ON `job_file_ref` (`file_entry_id`,`source_id`,`role`);
CREATE INDEX `fe_deleted_at_idx` ON `file_entry` (`deleted_at`);
CREATE INDEX `fe_created_at_idx` ON `file_entry` (`created_at`);
CREATE INDEX `fe_content_hash_idx` ON `file_entry` (`content_hash`);
CREATE UNIQUE INDEX `fe_external_path_lower_unique_idx` ON `file_entry` (lower("external_path"));
CREATE INDEX `fe_external_path_idx` ON `file_entry` (`external_path`);
CREATE INDEX `topic_last_activity_at_idx` ON `topic` (`last_activity_at`);
CREATE INDEX `topic_updated_at_idx` ON `topic` (`updated_at`);
CREATE INDEX `topic_order_key_idx` ON `topic` (`order_key`);
CREATE INDEX `topic_assistant_id_idx` ON `topic` (`assistant_id`);
CREATE INDEX `thfr_entry_id_idx` ON `translate_history_file_ref` (`file_entry_id`);
CREATE INDEX `thfr_source_id_idx` ON `translate_history_file_ref` (`source_id`);
CREATE UNIQUE INDEX `thfr_unique_idx` ON `translate_history_file_ref` (`source_id`,`role`);
CREATE INDEX `agent_channel_session_channel_id_idx` ON `agent_channel_session` (`channel_id`);
CREATE UNIQUE INDEX `agent_channel_session_active_uniq` ON `agent_channel_session` (`channel_id`,`conversation_id`) WHERE "agent_channel_session"."is_active" = 1 AND "agent_channel_session"."conversation_id" IS NOT NULL;
CREATE INDEX `mcp_server_name_idx` ON `mcp_server` (`name`);
CREATE INDEX `mcp_server_is_active_idx` ON `mcp_server` (`is_active`);
CREATE INDEX `mcp_server_sort_order_idx` ON `mcp_server` (`sort_order`);
CREATE INDEX `prompt_binding_target_idx` ON `prompt_binding` (`target_type`,`target_id`,`prompt_id`);
CREATE INDEX `prompt_binding_target_order_key_idx` ON `prompt_binding` (`target_type`,`target_id`,`order_key`);
CREATE INDEX `prompt_order_key_idx` ON `prompt` (`order_key`);
CREATE INDEX `message_created_at_id_idx` ON `message` ("created_at" desc,"id" asc);
CREATE INDEX `mafr_entry_id_idx` ON `mini_app_file_ref` (`file_entry_id`);
CREATE INDEX `mafr_source_id_idx` ON `mini_app_file_ref` (`source_id`);
CREATE UNIQUE INDEX `mafr_source_logical_name_unique_idx` ON `mini_app_file_ref` (`source_id`,`logical_name`);
CREATE UNIQUE INDEX `mag_app_permission_unique_idx` ON `mini_app_grant` (`app_id`,`permission`);
CREATE UNIQUE INDEX `ai_usage_record_request_id_idx` ON `ai_usage_record` (`request_id`);
CREATE INDEX `ai_usage_record_created_at_idx` ON `ai_usage_record` (`created_at`);
CREATE INDEX `ai_usage_record_message_created_idx` ON `ai_usage_record` (`message_kind`,`message_id`,`created_at`);
CREATE INDEX `ai_usage_record_provider_created_idx` ON `ai_usage_record` (`provider_id`,`created_at`);
CREATE INDEX `ai_usage_record_model_created_idx` ON `ai_usage_record` (`model_id`,`created_at`);
CREATE INDEX `ai_usage_record_api_key_created_idx` ON `ai_usage_record` (`api_key_id`,`created_at`);
CREATE INDEX `ai_usage_record_source_created_idx` ON `ai_usage_record` (`source_type`,`source_id`,`created_at`);
CREATE INDEX `mini_app_status_order_key_idx` ON `mini_app` (`status`,`order_key`);
CREATE INDEX `mini_app_preset_mini_app_id_idx` ON `mini_app` (`preset_mini_app_id`);
CREATE INDEX `message_model_id_idx` ON `message` (`model_id`);
CREATE INDEX `browser_visit_time_idx` ON `browser_visit` (`visited_at`,`id`);
CREATE UNIQUE INDEX `browser_visit_source_key_idx` ON `browser_visit` (`source_key`);
CREATE UNIQUE INDEX `api_gateway_paired_device_peer_identity_unique_idx` ON `api_gateway_paired_device` (`peer_identity`);
CREATE INDEX `diagnostic_report_submitted_at_idx` ON `diagnostic_report` (`submitted_at`,`report_id`);
CREATE INDEX `knowledge_base_group_id_order_key_idx` ON `knowledge_base` (`group_id`,`order_key`);
CREATE INDEX `knowledge_item_base_type_created_idx` ON `knowledge_item` (`base_id`,`type`,`created_at`);
CREATE INDEX `knowledge_item_base_group_created_idx` ON `knowledge_item` (`base_id`,`group_id`,`created_at`);
CREATE UNIQUE INDEX `knowledge_item_baseId_id_unique` ON `knowledge_item` (`base_id`,`id`);
CREATE UNIQUE INDEX `agent_runtime_backend_locator_uniq` ON `agent_runtime_backend` (`locator`);
CREATE INDEX `agent_session_context_backend_idx` ON `agent_session_context` (`backend_id`);
CREATE UNIQUE INDEX `agent_session_context_native_uniq` ON `agent_session_context` (`session_id`,`backend_id`,`native_thread_id`);
CREATE UNIQUE INDEX `agent_session_context_anchor_uniq` ON `agent_session_context` (`session_id`,`anchor_message_id`);
CREATE UNIQUE INDEX `agent_session_context_child_uniq` ON `agent_session_context` (`parent_context_id`,`native_thread_id`);
CREATE UNIQUE INDEX `notification_record_event_key_idx` ON `notification_record` (`event_key`);
CREATE INDEX `notification_record_time_idx` ON `notification_record` (`created_at`,`id`);
CREATE INDEX `notification_record_category_time_idx` ON `notification_record` (`category`,`created_at`,`id`);
CREATE INDEX `agent_session_order_key_idx` ON `agent_session` (`order_key`);
CREATE INDEX `agent_session_task_idx` ON `agent_session` (`task_id`);
CREATE UNIQUE INDEX `agent_session_task_reuse_uq` ON `agent_session` (`task_id`) WHERE "agent_session"."is_task_reuse_target" = 1;
CREATE INDEX `agent_session_owner_idx` ON `agent_session` (`owner_session_id`);
CREATE INDEX `agent_session_last_activity_at_idx` ON `agent_session` (`last_activity_at`);
CREATE INDEX `agent_session_updated_at_idx` ON `agent_session` (`updated_at`);
CREATE INDEX `aafr_entry_id_idx` ON `assistant_avatar_file_ref` (`file_entry_id`);
CREATE UNIQUE INDEX `aafr_source_id_idx` ON `assistant_avatar_file_ref` (`source_id`);
CREATE INDEX `cmfr_entry_id_idx` ON `chat_message_file_ref` (`file_entry_id`);
CREATE INDEX `cmfr_source_id_idx` ON `chat_message_file_ref` (`source_id`);
CREATE UNIQUE INDEX `cmfr_unique_idx` ON `chat_message_file_ref` (`file_entry_id`,`source_id`,`role`);
CREATE INDEX `agafr_entry_id_idx` ON `agent_avatar_file_ref` (`file_entry_id`);
CREATE UNIQUE INDEX `agafr_source_id_idx` ON `agent_avatar_file_ref` (`source_id`);
CREATE INDEX `asmfr_entry_id_idx` ON `agent_session_message_file_ref` (`file_entry_id`);
CREATE INDEX `asmfr_source_id_idx` ON `agent_session_message_file_ref` (`source_id`);
CREATE UNIQUE INDEX `asmfr_unique_idx` ON `agent_session_message_file_ref` (`file_entry_id`,`source_id`,`role`);
CREATE UNIQUE INDEX `agent_session_message_session_id_uniq` ON `agent_session_message` (`session_id`,`id`);
CREATE UNIQUE INDEX `agent_session_message_native_input_uniq` ON `agent_session_message` (`input_context_id`,`native_input_id`);
CREATE INDEX `agent_session_message_parent_idx` ON `agent_session_message` (`session_id`,`parent_id`);
CREATE UNIQUE INDEX `agent_session_message_root_uniq` ON `agent_session_message` (`session_id`) WHERE "agent_session_message"."role" = 'root';
CREATE INDEX `agent_session_message_session_created_id_idx` ON `agent_session_message` (`session_id`,`created_at`,`id`);
CREATE INDEX `agent_session_message_created_at_id_idx` ON `agent_session_message` (`created_at` desc,`id` asc);
CREATE INDEX `agent_session_message_status_idx` ON `agent_session_message` (`status`);
CREATE INDEX `agent_session_message_model_id_idx` ON `agent_session_message` (`model_id`);
CREATE INDEX `agent_session_message_delivery_status_idx` ON `agent_session_message` (`delivery_status`);
CREATE INDEX `agent_session_message_delivery_turn_ref_idx` ON `agent_session_message` (`delivery_turn_ref`);
CREATE INDEX `agent_session_message_delivery_sender_idx` ON `agent_session_message` (`delivery_sender_session_id`,`created_at`,`id`);
CREATE UNIQUE INDEX `agent_session_message_delivery_reply_uniq` ON `agent_session_message` (`delivery_in_reply_to`);
CREATE UNIQUE INDEX `agent_session_message_fts_rowid_uniq` ON `agent_session_message` (`fts_rowid`);
