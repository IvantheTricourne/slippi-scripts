const http = require('http');
const formidable = require('formidable');
const { getStats } = require('./stats.js');

const server = http.createServer((req, res) => {
    if (req.url === '/stats/upload' && req.method.toLowerCase() === 'post') {
        console.log('Incoming stats request...');
        // parse a file upload
        const form = formidable({ multiples: true });
        form.parse(req, (err, fields, files) => {
            // get file paths
            var filePaths = [];
            if (files.multipleFiles.length === undefined) { // handle single files
                filePaths.push(files.multipleFiles.path);
            } else {
                filePaths = files.multipleFiles
                    .map(file => {
                        return file.path;
                    });
            }
            // write stats response
            let stats = getStats(filePaths);
            res.writeHead(200, { 'content-type': 'application/json' });
            res.write(JSON.stringify(stats));
            res.end();
        });
        return;
    }
    // show a file upload form
    res.writeHead(200, { 'content-type': 'text/html' });
    res.end(`
    <h2><code>Slipi Server With Node.js</code></h2>
    <form action="/stats/upload" enctype="multipart/form-data" method="post">
      <div>File: <input type="file" name="multipleFiles" multiple="multiple" /></div>
      <input type="submit" value="Upload" />
    </form>
  `);

});

server.listen(8080, () => {
    console.log('Server listening on http://localhost:8080/ ...');
});
