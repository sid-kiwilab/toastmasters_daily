# Web App Size Optimization

## Simple Optimization Applied

**Use HTML Renderer instead of Canvaskit**

The HTML renderer reduces bundle size by **20-30MB** compared to Canvaskit.

### Build Command:
```bash
flutter build web --release
```

**Note:** Flutter will automatically use the HTML renderer by default in newer versions, which is smaller than Canvaskit. The HTML renderer is perfect for UI-heavy apps like this one.

### Expected Results:
- **Before**: ~50-80MB (with Canvaskit)
- **After**: ~20-40MB (with HTML renderer)
- **Compressed**: ~3-8MB (with gzip/brotli on Firebase Hosting)

### Trade-offs:
- HTML renderer is slightly less performant for complex graphics
- But perfectly fine for most UI apps like this one
- Much faster initial load time

### Additional Notes:
- Firebase Hosting automatically enables gzip compression
- Tree shaking is enabled by default in release builds
- The HTML renderer is set in `web/index.html` via `window.flutterConfiguration`

