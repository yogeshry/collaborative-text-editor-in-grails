package collaborativetexteditor
import org.springframework.messaging.handler.annotation.MessageMapping
import org.springframework.messaging.handler.annotation.SendTo

class WebSocketController {
    def CRDT = []
    def Char = []
    def queue = 0
    def exe = 1
    def sema = 2
    def offset = 0
    static  def delete(CRDT,Ch) {
        for (def i = 0; i < CRDT.size(); i++) {
            if (CRDT[i][1] == Ch[1] && CRDT[i][2] == Ch[2]) {
                  CRDT.remove(i)
//                for(def j=0;j<CRDT.size();j++){
//                    println(CRDT[j])
//                }
//                println("")
//
            }
        }
    }
    static def compareGpos(pos1,pos2){
        if(pos1 instanceof List || pos2 instanceof List){
            def x1,y1,x2,y2
            if(pos1 instanceof List){
                x1 = pos1[0]
                x2 = pos1[1]
            }
            else {
                x1 = pos1
                x2 = pos1
            }
            if(pos2 instanceof List){
                y1 = pos2[0]
                y2 = pos2[1]
            }
            else {
                y1 = pos2
                y2 = pos2
            }
            def firstElementComparison = compareGpos(x1,y1)
            def secondElementComparison = compareGpos(x2,y2)
            if (firstElementComparison>=0){
                if (firstElementComparison==0){
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
    static def update(CRDT,Char,prevGpos){
        def steps = 40
        if(CRDT.size() == 0){
            CRDT.push(Char)
        }
        else {
            def sd = CRDT.size()
            for (def x = steps; x < sd + steps; x++) {
                def b
                if (x < sd) {
                    b = compareGpos(Char[3], CRDT[x][3])
                } else {
                    b = -1
                }
//                println(x)

                if (b == -1) {
                    for (def i = x-steps; i < x+1; i++) {
                        //println(CRDT.size())
                       // println(i)
                        def a = compareGpos(Char[3], CRDT[i][3])
                        //println(a)
                        def gposLeft
                        if (a == -1) {
                            if (i == 0) {
                                gposLeft = -1
                            } else {
                                gposLeft = CRDT[i - 1][3]
                            }
                            Char[3] = gposLeft + (-gposLeft + CRDT[i][3]) / 10
                            CRDT.add(i, Char)
                            break
                        } else if (i == sd - 1) {
                            if (CRDT[-1][3] instanceof List) {
                                Char[3] = CRDT[-1][3][1]
                            } else {
                                Char[3] = CRDT[-1][3] + 1
                            }
                            CRDT.push(Char)
                            break
                        }
                    }
                    break
                }
                x = x+steps-1
            }
        }
        if(prevGpos != Char[3]){
            Char[6] = 1
        }
    }
    def index() {}
    def join(String nickname) {
        sema = 0
        if ( nickname.trim() == '' ) {
            redirect(action:'index')
        } else {
            session.siteId = UUID.randomUUID().toString()
            session.nickname = nickname
            session.offset = offset
            session.initContent = CRDT.toString()
            render (view: 'editor')
            sleep(1000)
             sema = 2
        }
    }

    @MessageMapping("/hello")
    @SendTo("/topic/hello")
    protected String hello(String message) {
        def limit = 40
        queue = queue + 1
        def q = queue
        while(q!=exe&&limit>1){
            limit = limit - 1
           // println("sema1")
            sleep(1)

        }
        while(sema != 2){
            sleep(1)

        }
        sema = 0

        Char = Eval.me(message)
        //eval converts string to var
        Char[2] = '"'+Char[2].toString()+'"'
        if(Char[0]=="delete"){
            Char[0] = '"'+Char[0].toString()+'"'
            Char[3] = '"'+Char[3].toString()+'"'
         delete(CRDT,Char)
            exe = exe + 1
            sema = 2
            return Char.toString()
        }
        Char[0] = '"'+Char[0].toString()+'"'
        def prevGpos = Char[3]
        update(CRDT,Char,prevGpos)
        exe = exe + 1
        sema = 2
        return Char.toString()
    }
}