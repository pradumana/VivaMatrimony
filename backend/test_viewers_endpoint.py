"""
Quick test script to verify the profile viewers endpoint.
Run with: python test_viewers_endpoint.py
"""
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text
import os
from dotenv import load_dotenv

load_dotenv()

async def test_viewers_query():
    """Test the profile viewers SQL query directly."""
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        print("ERROR: DATABASE_URL not set in .env")
        return
    
    # Convert postgres:// to postgresql+asyncpg://
    if database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql+asyncpg://", 1)
    elif database_url.startswith("postgresql://"):
        database_url = database_url.replace("postgresql://", "postgresql+asyncpg://", 1)
    
    engine = create_async_engine(database_url, echo=True)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as db:
        # First, check if profile_views table exists and has data
        result = await db.execute(text("SELECT COUNT(*) FROM profile_views"))
        count = result.scalar()
        print(f"\n✓ profile_views table has {count} rows")
        
        if count == 0:
            print("\n⚠ No profile views in database. The table exists but is empty.")
            print("This is normal if no one has viewed any profiles yet.")
            return
        
        # Get a sample user_id to test with
        result = await db.execute(text("SELECT DISTINCT viewed_id FROM profile_views LIMIT 1"))
        sample_user = result.scalar()
        
        if not sample_user:
            print("\n⚠ No viewed_id found in profile_views")
            return
        
        print(f"\n✓ Testing with user_id: {sample_user}")
        
        # Test the actual query from the endpoint
        result = await db.execute(
            text("""
                SELECT pv.viewer_id, pv.viewed_at,
                       p.full_name, p.date_of_birth,
                       ph.storage_path AS photo_path,
                       u.verification_status,
                       cl.state, cl.city
                FROM profile_views pv
                JOIN users u  ON u.id = pv.viewer_id AND u.deleted_at IS NULL
                JOIN profiles p ON p.user_id = pv.viewer_id
                LEFT JOIN photos ph ON ph.user_id = pv.viewer_id
                                   AND ph.is_primary = TRUE AND ph.deleted_at IS NULL
                LEFT JOIN current_locations cl ON cl.user_id = pv.viewer_id
                WHERE pv.viewed_id = :uid
                  AND NOT EXISTS (
                    SELECT 1 FROM blocks b
                    WHERE (b.blocker_id = :uid AND b.blocked_id = pv.viewer_id)
                       OR (b.blocker_id = pv.viewer_id AND b.blocked_id = :uid)
                  )
                ORDER BY pv.viewed_at DESC
                LIMIT 20
            """),
            {"uid": sample_user},
        )
        
        rows = result.fetchall()
        print(f"\n✓ Query returned {len(rows)} viewers")
        
        if rows:
            print("\n✓ Sample viewer data:")
            row = rows[0]
            print(f"  - viewer_id: {row.viewer_id}")
            print(f"  - full_name: {row.full_name}")
            print(f"  - viewed_at: {row.viewed_at}")
        
        print("\n✓ Backend query works correctly!")

if __name__ == "__main__":
    asyncio.run(test_viewers_query())
