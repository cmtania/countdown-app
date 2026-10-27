import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';

const include = ['CountdownApp', 'CountdownAppTests', 'CountdownApp.xcodeproj', 'project.yml', 'Package.swift', 'README.md', 'IMPLEMENTATION_PLAN.md', 'AGENTS.md', 'docs', 'scripts', 'package.json', 'package-lock.json', '.github', '.gitignore'];
const archive = 'artifacts/CountdownApp-1.0-native-source.tar.gz';
await fs.mkdir('artifacts', { recursive: true });
const result = spawnSync('tar', ['-czf', archive, ...include], { encoding: 'utf8' });
if (result.error) throw result.error;
if (result.status !== 0) throw new Error(result.stderr);
const listing = spawnSync('tar', ['-tzf', archive], { encoding: 'utf8' });
if (listing.status !== 0) throw new Error(listing.stderr);
const paths = listing.stdout.trim().split(/\r?\n/);
if (!paths.includes('project.yml')) throw new Error('XcodeGen project spec missing from source archive');
if (paths.some(p => p.startsWith('/') || p.split('/').includes('..') || /node_modules|\.tools|\.git\//.test(p))) throw new Error('Unexpected archive path');
const digest = crypto.createHash('sha256').update(await fs.readFile(archive)).digest('hex');
await fs.writeFile(`${archive}.sha256`, `${digest}  CountdownApp-1.0-native-source.tar.gz\n`);
console.log(`Packaged ${paths.length} source entries: ${archive}\nSHA-256 ${digest}`);
