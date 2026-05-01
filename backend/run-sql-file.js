const fs = require('fs');
const path = require('path');
require('dotenv').config();

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
  console.error('Please add SUPABASE_SERVICE_ROLE_KEY to your .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function runSqlFile(filePath) {
  try {
    const sql = fs.readFileSync(filePath, 'utf8');
    console.log(`Running SQL file: ${filePath}`);
    console.log('SQL content preview:', sql.substring(0, 200) + '...');

    // Split SQL into individual statements
    const statements = sql.split(';').map(s => s.trim()).filter(s => s.length > 0);

    for (const statement of statements) {
      if (statement.trim()) {
        console.log('Executing:', statement.substring(0, 100) + '...');
        const { error } = await supabase.rpc('exec', { query: statement });
        if (error) {
          console.error('Error executing statement:', error);
          console.error('Statement was:', statement);
        } else {
          console.log('Statement executed successfully');
        }
      }
    }

    console.log('All SQL statements processed');
  } catch (err) {
    console.error('Error reading or executing SQL file:', err);
  }
}

const fileName = process.argv[2];
if (!fileName) {
  console.error('Usage: node run-sql-file.js <filename>');
  process.exit(1);
}

const filePath = path.join(__dirname, fileName);
runSqlFile(filePath);