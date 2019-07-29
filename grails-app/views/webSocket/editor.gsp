<!DOCTYPE html>
<html>
<head>
    <meta name="layout" content="main"/>
    <asset:javascript src="application" />
    <asset:javascript src="spring-websocket" />
    <asset:javascript src="codemirror/codemirror.js"/>
    <asset:stylesheet src="codemirror/codemirror.css"/>
    <asset:javascript src="codemirror/mode/javascript/javascript.js"/>
</head>

<body>
<div><p>UserName: ${session.nickname}</p></div>
<div><p>SiteId: ${session.siteId}</p></div>
<div id="editor" ></div> <br>

<script type="text/javascript">
    var editor = CodeMirror(document.getElementById("editor"))
    var initContent = "${session.initContent}".replace(/&quot;/g, '\"')
    var CRDT_array = JSON.parse(initContent)
    var counter = 0
    var insertSema = false
    var charQ = []
    for(var i=0;i<CRDT_array.length;i++){
        var c = CRDT_array[i]
        var doc = editor.getDoc()
        var pos = coordFromIndex(i, editor);
        //todo what is c[5]
        if (c[5] === 0) {
            if (c[0] === ""){
                var charValue = ["",""]
            }
            else {
                var charValue = c[0]
            }
            // Insert the text at the given position.

            doc.replaceRange(charValue, pos, pos, 'insertText');
        }
    }
    $(function() {
        var offset = ${session.offset}
        var socket = new SockJS("${createLink(uri: '/stomp')}");
        var client = webstomp.over(socket);
        //codMirror editor triggers event on changes
            editor.on("change", function(_,changeObj) {
            //events that does not trigger remote functions i.e. local events
            if (changeObj.origin === "setValue") return;
            if (changeObj.origin === "insertText") return;
            if (changeObj.origin === "deleteText") return;
            //add siteId to changeObj
            changeObj.siteId = "${session.siteId}";
            //events that triggers remote functions
            switch(changeObj.origin) {
                case 'redo':
                case 'undo':
                    console.log(changeObj)
                    if(changeObj.removed[0]!==""||changeObj.removed.length!==1){
                        processDelete(changeObj,client)
                    }
                    if(changeObj.text[0]!==""||changeObj.text.length!==1){
                        bulkInsert(changeObj,client)
                    }                    break;
                case '*compose':
                case 'paste':
                    bulkInsert(changeObj,client);
                    break;
                case '+input':
                    console.log(changeObj);
                    //select and insert or replace a letter
                    if(changeObj.removed[0]!==""||changeObj.removed.length!==1){
                        processDelete(changeObj,client)
                    }
                    processInsert(changeObj,client);
                    break;
                case '+delete':
                case 'cut':
                    processDelete(changeObj,client);
                    break;
                default:
                    throw new Error("Unknown operation attempted in editor.");
            }
        });
        //message retrieval from backend
        client.connect({}, function () {
            client.subscribe("/topic/hello", function (message) {
                //convert string to Json
                while(insertSema===1){}
                insertSema = 2
                var Char = JSON.parse(message.body)
                if (Char[0]==="delete") {
                    for (var i = 0; i < CRDT_array.length; i++) {
                        if (CRDT_array[i][1] === Char[1] && CRDT_array[i][2] === Char[2]) {

                            var doc = editor.getDoc()
                            var pos = coordFromIndex(i, editor);
                            CRDT_array.splice(i, 1);
                            if (Char[3] !== "") {
                                doc.replaceRange('', pos, {line: pos.line, ch: pos.ch + 1}, 'deleteText');
                            }
                            else {
                                doc.replaceRange('', pos, {line: pos.line + 1, ch: 0}, 'deleteText');

                            }
                        }
                    }
                }
                else if(Char[2] !== "${session.siteId}") {
                    remoteInsert(Char, editor)

                }
                else{
                    if(Char[6]===1){
                        for( var i = 0; i < CRDT_array.length; i++){

                            if ( CRDT_array[i][1] === Char[1] && CRDT_array[i][2] === Char[2]) {
                                var doc = editor.getDoc()
                                var pos = coordFromIndex(i, editor);
                                CRDT_array.splice(i, 1);
                                if (Char[0]!==""){
                                doc.replaceRange('',pos, {line:pos.line,ch:pos.ch+1}, 'deleteText');
                                }
                                else {
                                    doc.replaceRange('',pos, {line:pos.line+1,ch:0}, 'deleteText');

                                }
                               remoteInsert(Char, editor)

                                break;
                            }
                        }
                    }
                }

                insertSema = 0
            });
        });
    });

    function coordFromIndex(index,editor) {
        var coord
        var lines = editor.getValue().split('\n');
        var total = lines.length, pos = 0, line, ch, len;

        for (line = 0; line < total; line++) {
            len = lines[line].length+1;
            if (pos + len > index) { ch = index - pos; break; }
            pos += len;
        }
        coord = {line: line, ch: ch}

        return coord
    }
    function indexFromCoord(coord,editor) {
        try{var lines = editor.getValue().split('\n');}
        catch (e) {
            return 0
        }
        var index = 0,line;
        for (line = 0; line < coord.line; line++) {
            index += lines[line].length+1;
        }
        index += coord.ch;
        return index;
    }
    function remoteInsert(Char, editor){

        var gpos = Char[3]
        var steps = 40
        var index
        if(CRDT_array.length === 0){
            index = 0
            CRDT_array.push(Char)
        }
        else  {
            var sd = CRDT_array.length
            for(var x = steps; x<sd+steps; x++){

                if(x<sd){
                var b = compareGpos(gpos,CRDT_array[x][3])}
                else{
                    var b = -1
                }
                if (b===-1) {
                    for (var i = x - steps; i < x+1; i++) {

                        var a = compareGpos(gpos, CRDT_array[i][3])
                        if (a === -1) {

                            // Char[3] = [gposLeft,CRDT_array[i][3]]
                            CRDT_array.splice(i, 0, Char)
                            index = i
                            break;
                        }
                        else if (i === sd - 1) {
                            index = i + 1
                            CRDT_array.push(Char)
                            break;
                        }
                    }
                    break;
                }
                    x = x+steps-1
            }
        }

        // Fetch the current CodeMirror document.
        var doc = editor.getDoc()
        var pos = coordFromIndex(index, editor);
        if (Char[5] === 0) {
            if (Char[0] === ""){
                var charValue = ["",""]
            }
            else {
                var charValue = Char[0]
            }
            // Insert the text at the given position.

            doc.replaceRange(charValue, pos, pos, 'insertText');
        }
    }

    function processInsert(changeobj,client,x) {
        while(insertSema===2){}
        insertSema = 1

        var index = indexFromCoord(changeobj.from,editor)+(x||0)
        var chr = makeCharObject(changeobj.text[0],index)
        CRDT_array.splice(index,0,chr);
        insertSema = 0;
        var prevL = charQ.length
        //charQ is a queque for delay
        charQ.unshift(chr)
        var postL = charQ.length
        if(prevL===0&&postL===1) {
            var intr = setInterval(function () {
                dequeue(charQ.pop(),client);
                if(charQ.length ===0) clearInterval(intr);
            }, 100)
        }

    };
    function processDelete(changeobj,client) {

        while(insertSema===2){}
        insertSema = 1
        var index = indexFromCoord(changeobj.from,editor)
        var count = 0

        if(changeobj.removed===["",""])
        {count++}
        else {
            for(var i=0;i<changeobj.removed.length;i++){
                if(changeobj.removed[i].length===0){
                }
                else{
                    for(var j=0;j<changeobj.removed[i].length;j++){
                        count++
                    }
                }
                count++
            }
            count=count-1
        }


        for(var j=0;j<count;j++){
            var ch = ["delete",CRDT_array[index][1],CRDT_array[index][2],CRDT_array[index][0]]
            CRDT_array.splice(index,1);
            var prevL = charQ.length
            charQ.unshift(ch)
            var postL = charQ.length
            insertSema = 0;

            if(prevL===0&&postL===1) {
                var intr = setInterval(function () {
                    dequeue(charQ.pop(),client);
                    if(charQ.length ===0) clearInterval(intr);
                }, 100)
            }
        }


    };
    function bulkInsert(changeobj,client) {

        var obj = {text:"",from:changeobj.from}
        var x  = 0
        var len = changeobj.text.length
        for(var i=0;i<len;i++){
            var eFlag = 0
            obj.text = [changeobj.text[i]]
            var ob = {text:"",from:changeobj.from}
            var le = obj.text[0].length
            if(le>1){
                for(var j=0;j<le;j++){
                    ob.text = [obj.text[0].substr(j,1)]
                    processInsert(ob,client,x)
                    x+=1
                }
            }
            else{
                if(obj.text[0]===""){
                    eFlag = 1
                }
                processInsert(obj,client,x)
                x+=1
            }
            if(i<len-1 && eFlag!==1){
                ob.text=[""]
                processInsert(ob,client,x)
                x+=1
            }
        }
    }
    function dequeue(chr,client) {
        client.send("/app/hello", JSON.stringify(chr));
    }
    function makeCharObject(obj,index) {
        counter = counter + 1;
        var gpos;
        var gposRight;
        var gposLeft;
        if (CRDT_array.length<index+1){
            gpos = index+${session.offset};
            gposRight = -1;
        }
        else{
            if (index===0){
                gposLeft = -1;
            }
            else{
                gposLeft = CRDT_array[index-1][3]
            }
            gposRight = CRDT_array[index][3]
            gpos = gposLeft+(-gposLeft+gposRight)/10
        }
        //TODO:  fifth pos
        return [obj,counter,"${session.siteId}",gpos,gposRight,0,0];
    }
    function compareGpos(pos1,pos2){
        if(pos1.constructor === Array || pos2.constructor === Array){
            var x1,y1,x2,y2
            if(pos1.constructor === Array){
                x1 = pos1[0]
                x2 = pos1[1]
            }
            else {
                x1 = pos1
                x2 = pos1
            }
            if(pos2.constructor === Array){
                y1 = pos2[0]
                y2 = pos2[1]
            }
            else {
                y1 = pos2
                y2 = pos2
            }
            var firstElementComparison = compareGpos(x1,y1)
            var secondElementComparison = compareGpos(x2,y2)

            if (firstElementComparison>=0){
                if (firstElementComparison===0){
                    return secondElementComparison
                }
                else {
                    if(secondElementComparison<0){
                        return secondElementComparison}
                    else{
                        return firstElementComparison
                    }
                }
            }
            else {
                if(secondElementComparison<=0){
                    return firstElementComparison
                }
                else {
                    return secondElementComparison
                }
            }
        }
        else {
            if(pos1>pos2){
                return 1
            }
            else if(pos1<pos2){
                return -1
            }
            else {
                return 0
            }
        }
    }

</script>
</body>

</html>