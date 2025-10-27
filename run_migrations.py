#!/usr/bin/env python3
"""
Database Migration Script for IMPULSO-IA-v4
============================================
This script connects to Supabase and executes the database migrations safely.

Usage:
    python3 run_migrations.py

Requirements:
    pip install psycopg2-binary
"""

import psycopg2
from psycopg2 import sql
import sys
from datetime import datetime

# ============================================================================
# CONFIGURATION
# ============================================================================

DB_CONFIG = {
    'host': 'db.uosauvyafotuhktpjjkm.supabase.co',
    'port': 5432,
    'database': 'postgres',
    'user': 'postgres',
    'password': 'X@ngOgum150325'
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def print_header(text):
    print("\n" + "="*70)
    print(f"  {text}")
    print("="*70)

def print_step(step_num, text):
    print(f"\n[{step_num}] {text}")

def execute_query(cursor, query, description=""):
    """Execute a query and print result"""
    try:
        if description:
            print(f"   → {description}")
        cursor.execute(query)
        return True
    except Exception as e:
        print(f"   ❌ ERRO: {e}")
        return False

def verify_orphans(cursor, table, fk_column, ref_table, ref_column='id'):
    """Check for orphaned records before adding FK"""
    query = f"""
        SELECT COUNT(*) as orphans
        FROM {table} t
        LEFT JOIN {ref_table} r ON t.{fk_column} = r.{ref_column}
        WHERE r.{ref_column} IS NULL
          AND t.{fk_column} IS NOT NULL
    """
    cursor.execute(query)
    count = cursor.fetchone()[0]
    return count

# ============================================================================
# MIGRATION 001: Add company_id to ai_decisions
# ============================================================================

def migration_001_add_company_id(conn, cursor):
    print_header("MIGRATION 001: Add company_id to ai_decisions")

    # ETAPA 1: Verificar se coluna já existe
    print_step(1, "Verificando se company_id já existe...")
    cursor.execute("""
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'corev4_ai_decisions'
        AND column_name = 'company_id'
    """)

    if cursor.fetchone():
        print("   ⚠️  Coluna company_id já existe. Pulando migração 001.")
        return True

    print("   ✅ Coluna não existe. Continuando...")

    # ETAPA 2: Adicionar coluna como NULLABLE
    print_step(2, "Adicionando coluna company_id (nullable)...")
    if not execute_query(cursor,
        "ALTER TABLE corev4_ai_decisions ADD COLUMN company_id UUID;",
        "ALTER TABLE corev4_ai_decisions ADD COLUMN company_id UUID"):
        return False
    conn.commit()
    print("   ✅ Coluna adicionada")

    # ETAPA 3: Preencher company_id
    print_step(3, "Preenchendo company_id a partir de followup_executions...")
    cursor.execute("""
        UPDATE corev4_ai_decisions ad
        SET company_id = fe.company_id
        FROM corev4_followup_executions fe
        WHERE ad.followup_execution_id = fe.id
          AND ad.company_id IS NULL
    """)
    rows_updated = cursor.rowcount
    conn.commit()
    print(f"   ✅ {rows_updated} registros atualizados")

    # ETAPA 4: Verificar NULLs
    print_step(4, "Verificando se há registros sem company_id...")
    cursor.execute("""
        SELECT COUNT(*)
        FROM corev4_ai_decisions
        WHERE company_id IS NULL
    """)
    null_count = cursor.fetchone()[0]

    if null_count > 0:
        print(f"   ⚠️  AVISO: {null_count} registros ainda estão sem company_id")
        response = input("   Deseja atribuir à primeira empresa encontrada? (s/N): ")
        if response.lower() == 's':
            cursor.execute("""
                UPDATE corev4_ai_decisions
                SET company_id = (SELECT id FROM corev4_companies LIMIT 1)
                WHERE company_id IS NULL
            """)
            conn.commit()
            print("   ✅ Registros atualizados")
        else:
            print("   ❌ Migração cancelada. Corrija os dados manualmente.")
            return False
    else:
        print("   ✅ Todos os registros têm company_id")

    # ETAPA 5: Tornar NOT NULL
    print_step(5, "Tornando company_id obrigatório (NOT NULL)...")
    if not execute_query(cursor,
        "ALTER TABLE corev4_ai_decisions ALTER COLUMN company_id SET NOT NULL;",
        "ALTER COLUMN SET NOT NULL"):
        return False
    conn.commit()
    print("   ✅ Coluna agora é NOT NULL")

    # ETAPA 6: Adicionar Foreign Key
    print_step(6, "Adicionando Foreign Key constraint...")
    if not execute_query(cursor, """
        ALTER TABLE corev4_ai_decisions
        ADD CONSTRAINT fk_ai_decisions_company
        FOREIGN KEY (company_id)
        REFERENCES corev4_companies(id)
        ON DELETE CASCADE
    """, "ADD CONSTRAINT fk_ai_decisions_company"):
        return False
    conn.commit()
    print("   ✅ Foreign Key adicionada")

    # ETAPA 7: Criar índices
    print_step(7, "Criando índices de performance...")
    execute_query(cursor,
        "CREATE INDEX IF NOT EXISTS idx_ai_decisions_company_id ON corev4_ai_decisions(company_id);",
        "Índice simples")
    execute_query(cursor,
        "CREATE INDEX IF NOT EXISTS idx_ai_decisions_company_created ON corev4_ai_decisions(company_id, created_at DESC);",
        "Índice composto")
    conn.commit()
    print("   ✅ Índices criados")

    # ETAPA 8: Habilitar RLS
    print_step(8, "Habilitando Row Level Security...")
    execute_query(cursor,
        "ALTER TABLE corev4_ai_decisions ENABLE ROW LEVEL SECURITY;",
        "ENABLE RLS")
    conn.commit()

    # ETAPA 9: Criar políticas RLS
    print_step(9, "Criando políticas RLS...")

    policies = [
        ("SELECT", "Users can view their company AI decisions"),
        ("INSERT", "Users can insert AI decisions for their company"),
        ("UPDATE", "Users can update their company AI decisions"),
        ("DELETE", "Users can delete their company AI decisions")
    ]

    for cmd, policy_name in policies:
        cursor.execute(f"DROP POLICY IF EXISTS \"{policy_name}\" ON corev4_ai_decisions;")

        if cmd == "SELECT":
            cursor.execute(f"""
                CREATE POLICY "{policy_name}"
                ON corev4_ai_decisions FOR {cmd}
                USING (
                    company_id = (current_setting('app.current_company_id', true))::uuid
                )
            """)
        elif cmd == "INSERT":
            cursor.execute(f"""
                CREATE POLICY "{policy_name}"
                ON corev4_ai_decisions FOR {cmd}
                WITH CHECK (
                    company_id = (current_setting('app.current_company_id', true))::uuid
                )
            """)
        else:
            cursor.execute(f"""
                CREATE POLICY "{policy_name}"
                ON corev4_ai_decisions FOR {cmd}
                USING (
                    company_id = (current_setting('app.current_company_id', true))::uuid
                )
                WITH CHECK (
                    company_id = (current_setting('app.current_company_id', true))::uuid
                )
            """)
        print(f"   ✅ Política {cmd} criada")

    conn.commit()

    print_header("MIGRATION 001 COMPLETA ✅")
    return True

# ============================================================================
# MIGRATION 002: Add Missing Foreign Keys
# ============================================================================

def migration_002_add_foreign_keys(conn, cursor):
    print_header("MIGRATION 002: Add Missing Foreign Keys")

    foreign_keys = [
        {
            'name': 'fk_sequences_campaign',
            'table': 'corev4_followup_sequences',
            'column': 'campaign_id',
            'ref_table': 'corev4_followup_campaigns',
            'ref_column': 'id'
        },
        {
            'name': 'fk_stage_history_execution',
            'table': 'corev4_followup_stage_history',
            'column': 'followup_execution_id',
            'ref_table': 'corev4_followup_executions',
            'ref_column': 'id'
        },
        {
            'name': 'fk_lead_backup_company',
            'table': 'corev4_lead_state_backup',
            'column': 'company_id',
            'ref_table': 'corev4_companies',
            'ref_column': 'id'
        },
        {
            'name': 'fk_lead_backup_contact',
            'table': 'corev4_lead_state_backup',
            'column': 'contact_id',
            'ref_table': 'corev4_contacts',
            'ref_column': 'id'
        },
        {
            'name': 'fk_dedup_contact',
            'table': 'corev4_message_dedup',
            'column': 'contact_id',
            'ref_table': 'corev4_contacts',
            'ref_column': 'id'
        }
    ]

    for idx, fk in enumerate(foreign_keys, 1):
        print_step(idx, f"Adicionando FK: {fk['table']}.{fk['column']}")

        # Verificar se FK já existe
        cursor.execute("""
            SELECT constraint_name
            FROM information_schema.table_constraints
            WHERE table_name = %s
            AND constraint_name = %s
            AND constraint_type = 'FOREIGN KEY'
        """, (fk['table'], fk['name']))

        if cursor.fetchone():
            print(f"   ⚠️  FK {fk['name']} já existe. Pulando.")
            continue

        # Verificar órfãos
        orphan_count = verify_orphans(cursor, fk['table'], fk['column'],
                                       fk['ref_table'], fk['ref_column'])

        if orphan_count > 0:
            print(f"   ⚠️  AVISO: {orphan_count} registros órfãos encontrados!")
            print(f"   Tabela: {fk['table']}, Coluna: {fk['column']}")
            response = input("   Deseja deletar os registros órfãos? (s/N): ")

            if response.lower() == 's':
                cursor.execute(f"""
                    DELETE FROM {fk['table']}
                    WHERE {fk['column']} NOT IN (
                        SELECT {fk['ref_column']} FROM {fk['ref_table']}
                    )
                """)
                deleted = cursor.rowcount
                conn.commit()
                print(f"   ✅ {deleted} registros órfãos deletados")
            else:
                print("   ⚠️  Pulando esta FK. Corrija manualmente.")
                continue
        else:
            print("   ✅ Nenhum registro órfão encontrado")

        # Adicionar Foreign Key
        cursor.execute(f"""
            ALTER TABLE {fk['table']}
            ADD CONSTRAINT {fk['name']}
            FOREIGN KEY ({fk['column']})
            REFERENCES {fk['ref_table']}({fk['ref_column']})
            ON DELETE CASCADE
        """)
        conn.commit()
        print(f"   ✅ FK {fk['name']} adicionada")

        # Criar índice
        idx_name = f"idx_{fk['table'].replace('corev4_', '')}_{fk['column']}"
        cursor.execute(f"""
            CREATE INDEX IF NOT EXISTS {idx_name}
            ON {fk['table']}({fk['column']})
        """)
        conn.commit()
        print(f"   ✅ Índice {idx_name} criado")

    print_header("MIGRATION 002 COMPLETA ✅")
    return True

# ============================================================================
# VERIFICATION
# ============================================================================

def verify_migrations(cursor):
    print_header("VERIFICAÇÃO FINAL")

    print("\n📊 FOREIGN KEYS ADICIONADAS:")
    cursor.execute("""
        SELECT
            tc.table_name,
            tc.constraint_name,
            kcu.column_name,
            ccu.table_name AS references_table
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu
          ON tc.constraint_name = ccu.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_name IN (
              'corev4_ai_decisions',
              'corev4_followup_sequences',
              'corev4_followup_stage_history',
              'corev4_lead_state_backup',
              'corev4_message_dedup'
          )
        ORDER BY tc.table_name, tc.constraint_name
    """)

    for row in cursor.fetchall():
        print(f"   ✅ {row[0]}.{row[2]} → {row[3]} ({row[1]})")

    print("\n📊 POLÍTICAS RLS:")
    cursor.execute("""
        SELECT policyname, cmd
        FROM pg_policies
        WHERE tablename = 'corev4_ai_decisions'
        ORDER BY cmd
    """)

    for row in cursor.fetchall():
        print(f"   ✅ {row[1]}: {row[0]}")

    print("\n" + "="*70)
    print("  ✅ TODAS AS MIGRAÇÕES FORAM APLICADAS COM SUCESSO!")
    print("="*70)

# ============================================================================
# MAIN
# ============================================================================

def main():
    print_header(f"DATABASE MIGRATION - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    conn = None
    try:
        # Conectar
        print("\n🔌 Conectando ao Supabase...")
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = False
        cursor = conn.cursor()
        print("✅ Conectado!")

        # Executar migrações
        if not migration_001_add_company_id(conn, cursor):
            print("\n❌ Erro na Migration 001. Abortando.")
            conn.rollback()
            return 1

        if not migration_002_add_foreign_keys(conn, cursor):
            print("\n❌ Erro na Migration 002. Abortando.")
            conn.rollback()
            return 1

        # Verificar
        verify_migrations(cursor)

        # Fechar
        cursor.close()
        conn.close()

        print("\n✅ Script concluído com sucesso!")
        return 0

    except KeyboardInterrupt:
        print("\n\n⚠️  Script interrompido pelo usuário.")
        if conn:
            conn.rollback()
            conn.close()
        return 1

    except Exception as e:
        print(f"\n❌ ERRO FATAL: {e}")
        import traceback
        traceback.print_exc()
        if conn:
            conn.rollback()
            conn.close()
        return 1

if __name__ == "__main__":
    sys.exit(main())
