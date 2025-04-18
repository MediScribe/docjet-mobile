# Mermaid Diagram Guidelines

This document provides guidelines for creating consistent Mermaid diagrams throughout the DocJet Mobile documentation.

## General Rules

1. **Be consistent** - Use the same style, colors, and formatting across all diagrams
2. **Follow syntax exactly** - Mermaid is extremely sensitive to syntax; copy working patterns
3. **Keep it simple** - Focus on clarity over complexity
4. **Include explanatory text** - Add descriptions before and after each diagram

## Standard Color Scheme

### Layer Colors

| Layer            | Color                                     | Hex Code  | Usage                                       |
|------------------|-------------------------------------------|-----------|---------------------------------------------|
| Presentation     | Green                                     | `#0F9D58` | UI components, state management, screens    |
| Domain           | Red                                       | `#E64A45` | Core business entities, interfaces, services|
| Data             | Blue                                      | `#4285F4` | Repositories, data sources, API clients     |
| External         | Gray                                      | `#9E9E9E` | External services, 3rd party integrations   |

### Flow Section Colors

| Flow Type        | Color                                     | RGB Value with Opacity      |
|------------------|-------------------------------------------|---------------------------- |
| Login Flow       | Gray                                      | `rgb(80, 80, 80, 0.2)`      |
| Success Case     | Green                                     | `rgb(15, 157, 88, 0.2)`     |
| Refresh Flow     | Blue                                      | `rgb(66, 133, 244, 0.2)`    |
| Logout Flow      | Red                                       | `rgb(230, 74, 69, 0.2)`     |
| Error Flow       | Orange                                    | `rgb(230, 162, 60, 0.2)`    |

## Diagram Types and Syntax

### Flowcharts (Architecture Diagrams)

```
%%{init: {'flowchart': {'defaultRenderer': 'elk'}}}%%
graph TD
    A[Component A] --> B[Component B]
    
    subgraph "Layer Name"
        B
        C[Component C]
    end
    
    classDef domain fill:#E64A45,stroke:#222,stroke-width:2px,color:#fff,padding:15px;
    classDef data fill:#4285F4,stroke:#222,stroke-width:2px,color:#fff;
    classDef presentation fill:#0F9D58,stroke:#222,stroke-width:2px,color:#fff;
    classDef external fill:#9E9E9E,stroke:#222,stroke-width:1px,color:#fff;

    class [YourDomainNodes] domain;
    class [YourDataNodes] data;
    class [YourPresentationNodes] presentation;
    class [YourExternalNodes] external;
```

### Sequence Diagrams (Flow Diagrams)

```
%%{init: {'theme': 'base', 'themeVariables': { 
  'primaryColor': '#E64A45', 
  'primaryTextColor': '#fff', 
  'primaryBorderColor': '#222', 
  'lineColor': '#4285F4', 
  'secondaryColor': '#0F9D58', 
  'tertiaryColor': '#9E9E9E',
  'actorLineColor': '#e0e0e0',
  'noteBkgColor': '#8C5824',      
  'noteTextColor': '#fff'       
}}}%%
sequenceDiagram
    participant A as Component A
    participant B as Component B
    
    rect rgb(15, 157, 88, 0.2)
    Note over A, B: Success Path
    A->>B: Request
    B-->>A: Response
    end
```

## Common Issues and Solutions

1. **Colors not appearing in sequence diagrams**:
   - Ensure the init directive matches exactly (spacing matters)
   - Place rect blocks outside of alt/else structures
   - Don't add comments within the color values
   - Make separate rect sections for each complete flow

2. **Flowchart layout issues**:
   - Use the elk renderer for complex diagrams
   - Be explicit about layout direction (TB, LR, etc.)
   - Use subgraphs to group related components

3. **Syntax errors**:
   - Always validate diagrams at [Mermaid Live Editor](https://mermaid.live/)
   - Check for missing end tags, extra spaces in directives
   - When in doubt, copy a working pattern exactly

4. **Proper Flow Representation**:
   - Rather than using complex nesting of alt/else with colors
   - Show separate, complete flows for each scenario in different colored sections

## Examples

For specific examples, refer to:
- [`auth_architecture.md`](./auth_architecture.md) - Authentication architecture diagram example
- [`job_dataflow.md`](./job_dataflow.md) - Job data flow diagram example 