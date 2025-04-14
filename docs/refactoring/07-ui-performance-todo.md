# UI Performance Refactoring Todo List

## 1. Create a Specialized AudioSlider Component

- [ ] Create test file for AudioSlider
- [ ] Write test for slider behavior
- [ ] Write test for position updates
- [ ] Write performance test for slider
- [ ] Create `AudioSlider` widget
- [ ] Add `ValueNotifier` for slider position
- [ ] Implement `didUpdateWidget()` for state update control
- [ ] Create drag handling methods
- [ ] Implement slider UI with `ValueListenableBuilder`
- [ ] Add time display with formatted durations
- [ ] Ensure proper resource disposal
- [ ] Test with various durations and inputs
- [ ] Verify dragging and seeking works smoothly

## 2. Optimize Player Widget with ChangeNotifier

- [ ] Create test file for optimized player widget
- [ ] Write tests for widget state management
- [ ] Write tests for rebuild behavior
- [ ] Create or update AudioPlayerWidget
- [ ] Add `ValueNotifier`s for each dynamic property
- [ ] Update `didUpdateWidget()` to only set values when changed
- [ ] Isolate rebuilds with `ValueListenableBuilder`
- [ ] Use `RepaintBoundary` for player
- [ ] Implement error state rendering
- [ ] Ensure proper resource disposal
- [ ] Run performance tests
- [ ] Verify widget rebuilds are minimized

## 3. Apply Rendering Optimizations

- [ ] Create test file for rendering performance
- [ ] Write test for list rendering performance
- [ ] Create `AudioPlayerList` widget
- [ ] Implement rendering optimizations (e.g., `addRepaintBoundaries`)
- [ ] Create lightweight `_InactiveAudioItem` for inactive items
- [ ] Only render full player for active item
- [ ] Add rendering helpers to main screen
- [ ] Implement `buildWhen` for controlled rebuilds
- [ ] Skip rebuilds for minor position changes
- [ ] Test scrolling performance
- [ ] Verify rendering efficiency with Flutter DevTools

## 4. Implement Seek Debouncing in the Service Layer

- [ ] Update service tests for seek debouncing
- [ ] Write test for rapid seek operations
- [ ] Add debouncing fields to service
- [ ] Implement debounced seek method
- [ ] Add proper cleanup in dispose
- [ ] Test with rapid seek requests
- [ ] Verify final position is correct

## 5. Integration Testing and Optimization

- [ ] Create performance test scripts
- [ ] Benchmark UI responsiveness before/after
- [ ] Test on various device types
- [ ] Create memory cache for loaded files
- [ ] Add cache cleanup for deleted files
- [ ] Run final performance tests
- [ ] Verify improvements on different devices
- [ ] Document performance improvements 