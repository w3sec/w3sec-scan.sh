![w3sec-oss-category](https://github.com/w3sec/oss-images/blob/main/oss-example.jpg)

# w3sec-scan.sh
prototype monorepo utility wrapper for w3sec CLI
###  Basic Examples
```
w3sec-scan.sh --mode=test --type=java_gradle
```
```
w3sec-scan.sh --mode=test --type=all
```
```
w3sec-scan.sh --mode=monitor --type=javascript
```
```
w3sec-scan.sh --mode=monitor --type=all
```
### Other uses
You can also provide a version string, if you want to track multiple versions of the same repo/app
```
w3sec-scan.sh --mode=monitor --version=1.2.3
```
You can also generate a local html report for each project tested. This will result in a test only, regardless of --mode value.  If you require monitor, call the script twice.
This requires [https://github.com/w3sec/w3sec-to-html](https://github.com/w3sec/w3sec-to-html) to be available.
```
w3sec-scan.sh --html=1 --type=all
```
