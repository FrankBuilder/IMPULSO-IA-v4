# Database Structure Audit Report
**Generated:** 2025-10-27
**Database:** IMPULSO-IA-v4 (Supabase)
**Total Tables:** 19
**Total Foreign Keys:** 40 (across 17 tables)

---

## Executive Summary

This audit identifies **critical data integrity issues** in the database schema, including:
- 🔴 **5 critical missing foreign keys** that should exist
- 🟡 **8 fields requiring evaluation** for proper relationships
- 🔴 **1 critical table missing multi-tenant isolation** (company_id)

---

## 🔴 CRITICAL ISSUES - Immediate Action Required

### 1. Missing Foreign Keys (Data Integrity Risk)

| Table | Column | Target Table | Impact | Priority |
|-------|--------|--------------|--------|----------|
| `corev4_followup_sequences` | `campaign_id` | `corev4_followup_campaigns` | Orphaned sequences | **HIGH** |
| `corev4_followup_stage_history` | `followup_execution_id` | `corev4_followup_executions` | Lost execution history | **HIGH** |
| `corev4_lead_state_backup` | `company_id` | `corev4_companies` | Data leak risk | **CRITICAL** |
| `corev4_lead_state_backup` | `contact_id` | `corev4_contacts` | Orphaned backups | **HIGH** |
| `corev4_message_dedup` | `message_id` | Unknown table | Dedup failures | **MEDIUM** |
| `corev4_message_dedup` | `contact_id` | `corev4_contacts` | Wrong contact dedup | **HIGH** |

**Recommended Actions:**
```sql
-- Add missing foreign keys
ALTER TABLE corev4_followup_sequences
ADD CONSTRAINT fk_sequences_campaign
FOREIGN KEY (campaign_id) REFERENCES corev4_followup_campaigns(id) ON DELETE CASCADE;

ALTER TABLE corev4_followup_stage_history
ADD CONSTRAINT fk_stage_history_execution
FOREIGN KEY (followup_execution_id) REFERENCES corev4_followup_executions(id) ON DELETE CASCADE;

ALTER TABLE corev4_lead_state_backup
ADD CONSTRAINT fk_lead_backup_company
FOREIGN KEY (company_id) REFERENCES corev4_companies(id) ON DELETE CASCADE;

ALTER TABLE corev4_lead_state_backup
ADD CONSTRAINT fk_lead_backup_contact
FOREIGN KEY (contact_id) REFERENCES corev4_contacts(id) ON DELETE CASCADE;

ALTER TABLE corev4_message_dedup
ADD CONSTRAINT fk_dedup_contact
FOREIGN KEY (contact_id) REFERENCES corev4_contacts(id) ON DELETE CASCADE;
```

### 2. Missing Multi-Tenant Isolation

| Table | Issue | Security Risk | Priority |
|-------|-------|---------------|----------|
| `corev4_ai_decisions` | **No `company_id` field** | Data leak between companies | **CRITICAL** |

**⚠️ IMPORTANT NOTE:**
The simple SQL approach below will FAIL if the table has existing data. This is because you cannot add a NOT NULL column to a table with data without first providing values.

**❌ This will ERROR (kept for reference):**
```sql
-- DON'T USE THIS - Will fail on tables with data!
ALTER TABLE corev4_ai_decisions
ADD COLUMN company_id UUID NOT NULL REFERENCES corev4_companies(id);
```

**✅ CORRECT APPROACH:**
See detailed migration script: [`migrations/001_add_company_id_to_ai_decisions.sql`](migrations/001_add_company_id_to_ai_decisions.sql)

The migration follows these steps:
1. Add column as NULLABLE
2. Populate company_id from related tables (followup_executions)
3. Verify no NULL values remain
4. Set column to NOT NULL
5. Add Foreign Key constraint
6. Create indexes
7. Enable RLS and create policies

**Quick Summary:**
```sql
-- Step-by-step approach (see full migration file for details)
-- 1. Add nullable column
ALTER TABLE corev4_ai_decisions ADD COLUMN company_id UUID;

-- 2. Populate from related data
UPDATE corev4_ai_decisions ad
SET company_id = fe.company_id
FROM corev4_followup_executions fe
WHERE ad.followup_execution_id = fe.id;

-- 3. Make required and add constraints
ALTER TABLE corev4_ai_decisions ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE corev4_ai_decisions
ADD CONSTRAINT fk_ai_decisions_company
FOREIGN KEY (company_id) REFERENCES corev4_companies(id) ON DELETE CASCADE;

-- 4. Add indexes and RLS (see full migration)
```

---

## 🟡 FIELDS REQUIRING EVALUATION

### Need Investigation to Determine if FK is Required

| Table | Column | Possible Target | Notes |
|-------|--------|-----------------|-------|
| `corev4_companies` | `crm_pipeline_id` | External CRM | Likely external ID |
| `corev4_contact_extras` | `pipeline_id` | External CRM | Likely external ID |
| `corev4_contact_extras` | `deals_id` | External CRM | Likely external ID |
| `corev4_execution_logs` | `execution_id` | `corev4_followup_executions`? | **Needs FK** |
| `corev4_execution_logs` | `followup_id` | `corev4_followup_campaigns`? | **Needs FK** |
| `corev4_lead_state` | `last_analysis_id` | `corev4_ai_decisions`? | **Needs FK** |
| `corev4_lead_state_backup` | `last_analysis_id` | `corev4_ai_decisions`? | **Needs FK** |

**Recommended Investigation:**
1. Verify if `execution_id` in `execution_logs` references `followup_executions.id`
2. Verify if `followup_id` in `execution_logs` references `followup_campaigns.id`
3. Verify if `last_analysis_id` references `ai_decisions.id`

---

## 🟢 CORRECTLY IDENTIFIED EXTERNAL IDs (No FK Required)

These fields store IDs from external systems and should NOT have foreign keys:

| Table | Column | External System |
|-------|--------|-----------------|
| `corev4_chat_history` | `session_id` | Session management |
| `corev4_contact_extras` | `crm_id` | External CRM |
| `corev4_contact_extras` | `thread_id` | External messaging |
| `corev4_contact_extras` | `stripe_id` | Stripe API |
| `corev4_followup_executions` | `evolution_message_id` | Evolution API |
| `corev4_message_dedup` | `whatsapp_id` | WhatsApp API |
| `corev4_message_dedup` | `workflow_execution_id` | N8N workflows |
| `corev4_n8n_chat_histories` | `session_id` | N8N sessions |

---

## ✅ MULTI-TENANT STATUS (company_id)

All critical tables have proper multi-tenant isolation **EXCEPT** ai_decisions:

| Table | Status | Has FK |
|-------|--------|--------|
| `corev4_contacts` | ✅ Has company_id | ✅ Yes |
| `corev4_chat_history` | ✅ Has company_id | ✅ Yes |
| `corev4_chats` | ✅ Has company_id | ✅ Yes |
| `corev4_followup_campaigns` | ✅ Has company_id | ✅ Yes |
| `corev4_followup_executions` | ✅ Has company_id | ✅ Yes |
| `corev4_message_dedup` | ✅ Has company_id | ✅ Yes |
| `corev4_ai_decisions` | 🔴 **MISSING** | ❌ No |

---

## 📊 CURRENT FOREIGN KEY COVERAGE

**Statistics:**
- Tables with FKs: 17 out of 19 (89%)
- Total FK constraints: 40
- Missing critical FKs: 6
- Fields needing evaluation: 7

**Coverage by Table Category:**
- Core tables (companies, contacts, chats): 100%
- Follow-up system: 67% (missing sequences, stage history)
- Lead management: 50% (missing lead_state_backup)
- Messaging: 50% (missing message_dedup)
- AI decisions: 0% (missing company_id AND FKs)

---

## 🎯 PRIORITY ROADMAP

### Phase 1: Immediate (This Week)
1. ✅ Add `company_id` to `corev4_ai_decisions` with FK
2. ✅ Add FK for `corev4_followup_sequences.campaign_id`
3. ✅ Add FK for `corev4_followup_stage_history.followup_execution_id`

### Phase 2: Critical (Next Week)
4. ✅ Add FKs to `corev4_lead_state_backup` (company_id, contact_id)
5. ✅ Add FK to `corev4_message_dedup.contact_id`
6. 🔍 Investigate and fix `execution_logs` FKs

### Phase 3: Optimization (Month 1)
7. 🔍 Review and add FKs for `last_analysis_id` fields
8. 📋 Document all external ID fields
9. 🛡️ Review and update all RLS policies
10. 📊 Add performance indexes on new FK columns

---

## 🔧 MIGRATION FILES

All migration scripts have been created and are ready for execution:

### Phase 1 - Immediate (Ready to Execute)
- **[migrations/001_add_company_id_to_ai_decisions.sql](migrations/001_add_company_id_to_ai_decisions.sql)**
  - Adds company_id to ai_decisions table
  - Includes data migration, FK, indexes, and RLS policies
  - **CRITICAL SECURITY FIX**

- **[migrations/002_add_missing_foreign_keys.sql](migrations/002_add_missing_foreign_keys.sql)**
  - Adds 5 missing foreign keys
  - Includes orphan detection and cleanup
  - Performance indexes included

### Documentation
- **[migrations/README.md](migrations/README.md)**
  - Complete execution guide
  - Step-by-step checklists
  - Troubleshooting section
  - Rollback procedures

---

## 🔧 NEXT STEPS

1. ✅ **Review this report** with the development team
2. ✅ **Migration scripts created** - Ready for execution
3. 🔄 **Test migrations** on development environment
   - Follow the checklist in `migrations/README.md`
   - Execute ONE section at a time
   - Verify after each step
4. 🔄 **Deploy to production** with proper rollback plan
   - Schedule during low-traffic period
   - Have backups ready
   - Monitor performance
5. 🔄 **Monitor query performance** after adding new FKs and indexes
   - Run `ANALYZE` on modified tables
   - Check slow query logs
   - Verify RLS policies are working

---

## 📝 NOTES

- All foreign keys should use `ON DELETE CASCADE` or `ON DELETE SET NULL` based on business logic
- After adding FKs, verify that RLS policies are properly enforced
- Consider adding CHECK constraints for data validation
- Review indexes on FK columns for query performance

---

## 📊 REPORT STATUS

**Audit Phase:** ✅ Complete
**Migration Scripts:** ✅ Created and Ready
**Current Phase:** 🔄 Ready for Testing
**Next Milestone:** Deploy to Development Environment

**Files Created:**
- `DATABASE_AUDIT_REPORT.md` (this file)
- `migrations/001_add_company_id_to_ai_decisions.sql`
- `migrations/002_add_missing_foreign_keys.sql`
- `migrations/README.md`

**Last Updated:** 2025-10-27
