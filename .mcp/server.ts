#!/usr/bin/env node
/**
 * Model Context Protocol (MCP) Server for iOS App
 * Provides convention enforcement tools for Swift/SwiftUI/TCA codebase
 *
 * Tools:
 * - validate_swift_naming: Check Swift files follow naming conventions
 * - check_file_organization: Verify files are in correct directories
 * - validate_tca_feature: Validate TCA Feature structure
 */

import {Server} from '@modelcontextprotocol/sdk/server/index.js'
import {StdioServerTransport} from '@modelcontextprotocol/sdk/server/stdio.js'
import {CallToolRequestSchema, ListToolsRequestSchema} from '@modelcontextprotocol/sdk/types.js'
import * as fs from 'fs/promises'
import * as path from 'path'
import {fileURLToPath} from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const projectRoot = path.resolve(__dirname, '..')

// Create server instance
const server = new Server({name: 'ios-mcp-server', version: '1.0.0'}, {capabilities: {tools: {}}})

/**
 * Wrap handler result in MCP content format
 */
function wrapResult(result: unknown) {
  return {content: [{type: 'text', text: JSON.stringify(result, null, 2)}]}
}

// Type definitions
interface NamingViolation {
  file: string
  line: number
  name: string
  issue: string
  suggestion: string
}

interface OrganizationViolation {
  file: string
  issue: string
  expectedDirectory: string
  suggestion: string
}

interface TCAViolation {
  file: string
  line: number
  issue: string
  suggestion: string
}

// Naming patterns for Swift
const SWIFT_NAMING_RULES = {
  views: {suffix: 'View', pattern: /struct\s+(\w+View)\s*:\s*(some\s+)?View/},
  features: {suffix: 'Feature', pattern: /@Reducer\s+struct\s+(\w+Feature)/},
  clients: {suffix: 'Client', pattern: /struct\s+(\w+Client)\s*{/},
  errors: {suffix: 'Error', pattern: /enum\s+(\w+Error)\s*:\s*Error/},
  responses: {suffix: 'Response', pattern: /struct\s+(\w+Response)\s*:/},
  forbiddenSuffixes: ['Data'] // e.g., UserData should be User
}

// Directory organization rules
const ORGANIZATION_RULES = {
  Views: ['*View.swift'],
  Features: ['*Feature.swift'],
  Models: ['User.swift', 'Device.swift', 'File.swift', '*Response.swift'],
  Dependencies: ['*Client.swift'],
  Enums: ['FileStatus.swift', '*Enum.swift']
}

/**
 * Parse a Swift file and extract type definitions
 */
async function parseSwiftFile(filePath: string): Promise<{
  types: {name: string; kind: string; line: number}[]
  content: string
}> {
  const content = await fs.readFile(filePath, 'utf-8')
  const lines = content.split('\n')
  const types: {name: string; kind: string; line: number}[] = []

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    const lineNum = i + 1

    // Match struct definitions
    const structMatch = line.match(/(?:public\s+)?struct\s+(\w+)/)
    if (structMatch) {
      types.push({name: structMatch[1], kind: 'struct', line: lineNum})
    }

    // Match class definitions
    const classMatch = line.match(/(?:public\s+)?(?:final\s+)?class\s+(\w+)/)
    if (classMatch) {
      types.push({name: classMatch[1], kind: 'class', line: lineNum})
    }

    // Match enum definitions
    const enumMatch = line.match(/(?:public\s+)?enum\s+(\w+)/)
    if (enumMatch) {
      types.push({name: enumMatch[1], kind: 'enum', line: lineNum})
    }

    // Match protocol definitions
    const protocolMatch = line.match(/(?:public\s+)?protocol\s+(\w+)/)
    if (protocolMatch) {
      types.push({name: protocolMatch[1], kind: 'protocol', line: lineNum})
    }
  }

  return {types, content}
}

/**
 * Validate Swift naming conventions
 */
async function validateSwiftNaming(args: {file?: string; query: 'validate' | 'suggest' | 'all'}): Promise<{
  valid: boolean
  violations: NamingViolation[]
  suggestions: {current: string; suggested: string; reason: string}[]
}> {
  const {file, query} = args
  const violations: NamingViolation[] = []
  const suggestions: {current: string; suggested: string; reason: string}[] = []

  // Get files to check
  const filesToCheck: string[] = []
  if (file) {
    filesToCheck.push(path.isAbsolute(file) ? file : path.join(projectRoot, file))
  } else {
    // Check all Swift files in App directory
    const appDir = path.join(projectRoot, 'App')
    const walkDir = async (dir: string): Promise<void> => {
      const entries = await fs.readdir(dir, {withFileTypes: true})
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name)
        if (entry.isDirectory()) {
          await walkDir(fullPath)
        } else if (entry.name.endsWith('.swift')) {
          filesToCheck.push(fullPath)
        }
      }
    }
    await walkDir(appDir)
  }

  for (const filePath of filesToCheck) {
    try {
      const {types, content} = await parseSwiftFile(filePath)
      const relativePath = path.relative(projectRoot, filePath)

      for (const type of types) {
        // Check for forbidden suffixes (e.g., *Data instead of plain name)
        for (const forbidden of SWIFT_NAMING_RULES.forbiddenSuffixes) {
          if (type.name.endsWith(forbidden) && type.name !== forbidden) {
            const suggested = type.name.slice(0, -forbidden.length)
            violations.push({
              file: relativePath,
              line: type.line,
              name: type.name,
              issue: `Type name '${type.name}' uses forbidden suffix '${forbidden}'`,
              suggestion: `Rename to '${suggested}'`
            })
            suggestions.push({
              current: type.name,
              suggested,
              reason: `Domain models should use simple names without '${forbidden}' suffix`
            })
          }
        }

        // Check Views are in Views directory
        if (type.name.endsWith('View') && type.kind === 'struct') {
          if (!relativePath.includes('/Views/') && !relativePath.includes('View.swift')) {
            violations.push({
              file: relativePath,
              line: type.line,
              name: type.name,
              issue: `View '${type.name}' is not in the Views directory`,
              suggestion: `Move to App/Views/${type.name}.swift`
            })
          }
        }

        // Check Features are in Features directory
        if (type.name.endsWith('Feature') && content.includes('@Reducer')) {
          if (!relativePath.includes('/Features/')) {
            violations.push({
              file: relativePath,
              line: type.line,
              name: type.name,
              issue: `Feature '${type.name}' is not in the Features directory`,
              suggestion: `Move to App/Features/${type.name}.swift`
            })
          }
        }
      }

      // Check for FileStatus as String instead of enum
      if (content.includes('status: String?') || content.includes('status: String')) {
        const lineNum = content.split('\n').findIndex((l) => l.includes('status: String')) + 1
        violations.push({
          file: relativePath,
          line: lineNum,
          name: 'status',
          issue: 'Property status should use FileStatus enum instead of String',
          suggestion: 'Change type to FileStatus?'
        })
      }
    } catch {
      // Skip files that can't be read
    }
  }

  return {
    valid: violations.length === 0,
    violations,
    suggestions: query === 'suggest' || query === 'all' ? suggestions : []
  }
}

/**
 * Check file organization
 */
async function checkFileOrganization(args: {query: 'check' | 'all'}): Promise<{
  organized: boolean
  violations: OrganizationViolation[]
  structure: Record<string, string[]>
}> {
  const violations: OrganizationViolation[] = []
  const structure: Record<string, string[]> = {}

  const appDir = path.join(projectRoot, 'App')

  // Check each expected directory
  for (const [dir, patterns] of Object.entries(ORGANIZATION_RULES)) {
    const dirPath = path.join(appDir, dir)
    structure[dir] = []

    try {
      const files = await fs.readdir(dirPath)
      structure[dir] = files.filter((f) => f.endsWith('.swift'))
    } catch {
      // Directory doesn't exist
      violations.push({
        file: `App/${dir}/`,
        issue: `Directory '${dir}' does not exist`,
        expectedDirectory: `App/${dir}`,
        suggestion: `Create directory App/${dir}/ and move appropriate files`
      })
    }
  }

  // Check for misplaced files
  const walkDir = async (dir: string): Promise<void> => {
    let entries
    try {
      entries = await fs.readdir(dir, {withFileTypes: true})
    } catch {
      return
    }

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name)
      const relativePath = path.relative(projectRoot, fullPath)

      if (entry.isDirectory()) {
        await walkDir(fullPath)
      } else if (entry.name.endsWith('.swift')) {
        // Check if file is in wrong directory
        const fileName = entry.name

        // Views should be in Views/
        if (fileName.endsWith('View.swift') && !relativePath.includes('/Views/')) {
          // Skip RootView which might be at app level
          if (fileName !== 'RootView.swift') {
            violations.push({
              file: relativePath,
              issue: `View file '${fileName}' is not in Views directory`,
              expectedDirectory: 'App/Views',
              suggestion: `Move to App/Views/${fileName}`
            })
          }
        }

        // Features should be in Features/
        if (fileName.endsWith('Feature.swift') && !relativePath.includes('/Features/')) {
          violations.push({
            file: relativePath,
            issue: `Feature file '${fileName}' is not in Features directory`,
            expectedDirectory: 'App/Features',
            suggestion: `Move to App/Features/${fileName}`
          })
        }

        // Clients should be in Dependencies/
        if (fileName.endsWith('Client.swift') && !relativePath.includes('/Dependencies/')) {
          violations.push({
            file: relativePath,
            issue: `Client file '${fileName}' is not in Dependencies directory`,
            expectedDirectory: 'App/Dependencies',
            suggestion: `Move to App/Dependencies/${fileName}`
          })
        }
      }
    }
  }

  await walkDir(appDir)

  return {
    organized: violations.length === 0,
    violations,
    structure
  }
}

/**
 * Validate TCA Feature structure
 */
async function validateTCAFeature(args: {file?: string; query: 'validate' | 'all'}): Promise<{
  valid: boolean
  violations: TCAViolation[]
  features: {name: string; file: string; hasReducer: boolean; hasState: boolean; hasAction: boolean}[]
}> {
  const {file} = args
  const violations: TCAViolation[] = []
  const features: {name: string; file: string; hasReducer: boolean; hasState: boolean; hasAction: boolean}[] = []

  // Get files to check
  const filesToCheck: string[] = []
  if (file) {
    filesToCheck.push(path.isAbsolute(file) ? file : path.join(projectRoot, file))
  } else {
    // Check all Feature files
    const featuresDir = path.join(projectRoot, 'App', 'Features')
    try {
      const files = await fs.readdir(featuresDir)
      for (const f of files) {
        if (f.endsWith('.swift')) {
          filesToCheck.push(path.join(featuresDir, f))
        }
      }
    } catch {
      // Features directory doesn't exist
    }

    // Also check for inline features in Views
    const viewsDir = path.join(projectRoot, 'App', 'Views')
    try {
      const files = await fs.readdir(viewsDir)
      for (const f of files) {
        if (f.endsWith('.swift')) {
          filesToCheck.push(path.join(viewsDir, f))
        }
      }
    } catch {
      // Views directory doesn't exist
    }
  }

  for (const filePath of filesToCheck) {
    try {
      const content = await fs.readFile(filePath, 'utf-8')
      const relativePath = path.relative(projectRoot, filePath)
      const lines = content.split('\n')

      // Find @Reducer annotated structs
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i]
        const lineNum = i + 1

        if (line.includes('@Reducer')) {
          // Look for struct on next line(s)
          let featureName = ''
          for (let j = i; j < Math.min(i + 3, lines.length); j++) {
            const structMatch = lines[j].match(/struct\s+(\w+Feature)/)
            if (structMatch) {
              featureName = structMatch[1]
              break
            }
          }

          if (featureName) {
            const hasState = content.includes(`@ObservableState`) || content.includes(`struct State`)
            const hasAction = content.includes(`enum Action`) || content.includes(`case `)
            const hasReducer = content.includes(`var body:`) || content.includes(`Reduce {`)

            features.push({
              name: featureName,
              file: relativePath,
              hasReducer,
              hasState,
              hasAction
            })

            // Check for inline features in View files
            if (relativePath.includes('/Views/')) {
              violations.push({
                file: relativePath,
                line: lineNum,
                issue: `Feature '${featureName}' is defined inline in a View file`,
                suggestion: `Extract to App/Features/${featureName}.swift`
              })
            }

            // Check for @State or @StateObject in the file (anti-pattern with TCA)
            if (content.includes('@State ') || content.includes('@StateObject')) {
              const stateLineNum =
                lines.findIndex((l) => l.includes('@State ') || l.includes('@StateObject')) + 1
              violations.push({
                file: relativePath,
                line: stateLineNum,
                issue: 'Using @State/@StateObject alongside TCA is an anti-pattern',
                suggestion: 'Use TCA State for all state management'
              })
            }

            // Check for @Dependency usage
            if (!content.includes('@Dependency')) {
              violations.push({
                file: relativePath,
                line: lineNum,
                issue: `Feature '${featureName}' may not be using @Dependency for clients`,
                suggestion: 'Use @Dependency for injecting clients into features'
              })
            }
          }
        }
      }
    } catch {
      // Skip files that can't be read
    }
  }

  return {
    valid: violations.length === 0,
    violations,
    features
  }
}

// Define available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'validate_swift_naming',
        description: 'Validate Swift files follow naming conventions (Views, Features, Clients, no *Data suffix)',
        inputSchema: {
          type: 'object',
          properties: {
            file: {type: 'string', description: 'Specific file to validate (optional, validates all if omitted)'},
            query: {type: 'string', description: 'Query type (validate, suggest, all)', enum: ['validate', 'suggest', 'all']}
          },
          required: ['query']
        }
      },
      {
        name: 'check_file_organization',
        description: 'Verify files are in correct directories (Views/, Features/, Dependencies/, Models/)',
        inputSchema: {
          type: 'object',
          properties: {
            query: {type: 'string', description: 'Query type (check, all)', enum: ['check', 'all']}
          },
          required: ['query']
        }
      },
      {
        name: 'validate_tca_feature',
        description: 'Validate TCA Feature structure (@Reducer, State, Action, @Dependency)',
        inputSchema: {
          type: 'object',
          properties: {
            file: {type: 'string', description: 'Specific file to validate (optional, validates all if omitted)'},
            query: {type: 'string', description: 'Query type (validate, all)', enum: ['validate', 'all']}
          },
          required: ['query']
        }
      }
    ]
  }
})

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const {name, arguments: args} = request.params

  try {
    switch (name) {
      case 'validate_swift_naming':
        return wrapResult(await validateSwiftNaming(args as {file?: string; query: 'validate' | 'suggest' | 'all'}))

      case 'check_file_organization':
        return wrapResult(await checkFileOrganization(args as {query: 'check' | 'all'}))

      case 'validate_tca_feature':
        return wrapResult(await validateTCAFeature(args as {file?: string; query: 'validate' | 'all'}))

      default:
        throw new Error(`Unknown tool: ${name}`)
    }
  } catch (error) {
    return {content: [{type: 'text', text: `Error: ${error instanceof Error ? error.message : String(error)}`}]}
  }
})

// Start the server
async function main() {
  const transport = new StdioServerTransport()
  await server.connect(transport)
  console.error('iOS MCP Server running on stdio')
}

main().catch(console.error)
