<%@ page contentType="text/html;charset=UTF-8" %>
<html>
    <head>
        <title>Editor</title>
        <asset:javascript src="codemirror/codemirror.js"/>
        <asset:stylesheet src="codemirror/codemirror.css"/>
        <asset:javascript src="codemirror/mode/javascript/javascript.js"/>
        <asset:javascript src="peerjs/peer.min.js"/>
    </head>

    <style>
        body{
            background-color: #F0E8FE;
        }
    </style>

    <body>
        <div id="editor"></div> <br>
        <div id="linkContainer"></div>
        <div id="logContainer"></div>
        <g:actionSubmit value="GenerateLink" onclick="generateLink()"/>

    <button type="button" onclick="sayHi()">Say Hi!</button>
    
        <script>
            // initialize the editor
            var editor = CodeMirror(document.getElementById("editor"));

            function getPublicIP(){
                if (sessionStorage.getItem("ip-address") == null){
                    const Http = new XMLHttpRequest();
                    const url = "https://api.ipify.org";
                    Http.open("GET", url);
                    Http.send();
                    Http.onreadystatechange = (e) => {
                        sessionStorage.setItem("public-ip-address", Http.responseText);
                    }
                }

                return sessionStorage.getItem("public-ip-address");
            }

            function getLocalIP(){
                window.RTCPeerConnection = window.RTCPeerConnection || window.mozRTCPeerConnection
                    || window.webkitRTCPeerConnection;//compatibility for Firefox and chrome
                var pc = new RTCPeerConnection({iceServers:[]}), noop = function(){};
                pc.createDataChannel('');//create a bogus data channel
                pc.createOffer(pc.setLocalDescription.bind(pc), noop);// create offer and set local description
                pc.onicecandidate = function(ice) {
                    if (ice && ice.candidate && ice.candidate.candidate)
                    {
                        var myIP = /([0-9]{1,3}(\.[0-9]{1,3}){3}|[a-f0-9]{1,4}(:[a-f0-9]{1,4}){7})/.exec(ice.candidate.candidate)[1];
                        sessionStorage.setItem("local-ip-address", myIP);
                        pc.onicecandidate = noop;
                    }
                };
                return sessionStorage.getItem("local-ip-address");
            }

            // initialize the peer-to-peer communication methods
            function initPeer(){
                peer = new Peer();

                // set listeners for peers
                // emitted when a connection to the PeerServer is established
                peer.on('open', function(id){
                    console.log('My peer id is ', id);
                    sessionStorage.setItem("my-peer-id", id);
                });

                // emitted when a new data connection is established from the remote peer
                peer.on('connection', function(dataConnection){

                    // emitted when connection is established and ready to use
                    dataConnection.on('open', function(){

                        // emitted when data is received from the remote peer
                        dataConnection.on('data', function(data){
                            console.log("Received data from peer! ", data);
                        });
                    });

                    console.log('Remote peer established connection! ', dataConnection.peer);

                    var peers = sessionStorage.getItem("peers-list");
                    if (peers === null){
                        peers = [];
                    } else {
                        peers = JSON.parse(peers);

                    }
                    peers.push(dataConnection.peer);
                    sessionStorage.setItem("peers-list", JSON.stringify(peers));

                    // set the local dataConn here
                    dataConn = dataConnection;
                });
            }


            // generate the unique link for the document
            function generateLink(){
                let linkContainer = document.getElementById("linkContainer");
                linkContainer.innerHTML = "http://localhost:8080/" + "?srcPeerId=" + sessionStorage.getItem("my-peer-id");
            }

            // establish connection to peer if peerId is available
            function initConnectionToPeer(srcPeerId){

                // connect to the remote peer specified by srcPeerId
                // and return a data connection
                let dataConn = peer.connect(srcPeerId);

                // set listeners for data connection events
                // emitted when the connection is established and ready to use
                dataConn.on('open', function(){
                   console.log('The remote side has successfully connected!');
                });

                // emitted when data is received from the remote peer
                dataConn.on('data', function(data){

                    console.log('Received data from remote peer ', data);
                    logContainer.innerHTML = "Message from remote peer" + data;

                    // send the received data to all the peers
                    var peers = sessionStorage.getItem("peers-list");
                    if (peers === null){
                        peers = [];
                    } else {
                        peers = JSON.parse(peers);
                    }

                    for (peerId in peers){
                        let dataConn2Peer = peer.connect(peerId);
                        dataConn2Peer.send(data);
                    }

                });

                return dataConn;
            }

            function sayHi() {
                dataConn.send("Hi!");
            }

            let peer = null;
            let url = new URL(window.location.href);
            let srcPeerId = url.searchParams.get("srcPeerId");
            let dataConn = null;
            let logContainer = document.getElementById("logContainer");

            initPeer();

            if (srcPeerId === null){
                // do nothing
            } else {
                sessionStorage.setItem("src-peer-id", srcPeerId);
                dataConn = initConnectionToPeer(srcPeerId);
            }

        </script>
    </body>
</html>