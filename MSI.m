
-- TODO (SanyaSriv): Think about where to put timers 
-- One timer for every message that is being processed
-- We should have a queue of timers for the C1.
-- SanyaSriv: general note: I am not generating a special timer for pings, then we can resend it the next time
-- the timeout happens. We should not be failing forever

--Backend/Murphi/MurphiModular/Constants/GenConst
  ---- System access constants
  const
    ENABLE_QS: false;
    VAL_COUNT: 1;
    ADR_COUNT: 1;
  
  ---- System network constants
    O_NET_MAX: 10;
    U_NET_MAX: 10;
  
  ---- SSP declaration constants
    NrCachesL1C1: 3; -- I think we can just have 2 here
  
--Backend/Murphi/MurphiModular/GenTypes
  type
    ----Backend/Murphi/MurphiModular/Types/GenAdrDef
    Address: scalarset(ADR_COUNT);
    ClValue: 0..VAL_COUNT;
    
    ----Backend/Murphi/MurphiModular/Types/Enums/GenEnums
      ------Backend/Murphi/MurphiModular/Types/Enums/SubEnums/GenAccess
      PermissionType: enum {
        load, 
        store, 
        evict, 
        none
      };
      
      ------Backend/Murphi/MurphiModular/Types/Enums/SubEnums/GenMessageTypes
      MessageType: enum {
        GetSL1C1, 
        GetML1C1, 
        PutSL1C1, 
        Inv_AckL1C1, 
        GetM_Ack_DL1C1, 
        GetS_AckL1C1, 
        WBL1C1, 
        PutML1C1, 
        GetM_Ack_ADL1C1, 
        InvL1C1, 
        Put_AckL1C1, 
        Fwd_GetSL1C1, 
        Fwd_GetML1C1,

        -- TODO: add ping messages here
        PING,
        ACK_PING_SUCCESS,
        ACK_PING_FAILURE,
        PING_PROP
      };
      
      ------Backend/Murphi/MurphiModular/Types/Enums/SubEnums/GenArchEnums
      s_cacheL1C1: enum {
        cacheL1C1_S_store_GetM_Ack_AD,
        cacheL1C1_S_store,
        cacheL1C1_S_evict_x_I,
        cacheL1C1_S_evict,
        cacheL1C1_S,
        cacheL1C1_M_evict_x_I,
        cacheL1C1_M_evict,
        cacheL1C1_M,
        cacheL1C1_I_store_GetM_Ack_AD,
        cacheL1C1_I_store,
        cacheL1C1_I_load,
        cacheL1C1_I
        -- Not sure if we need more states. 
      };
      
      s_directoryL1C1: enum {
        directoryL1C1_S,
        directoryL1C1_M_GetS,
        directoryL1C1_M,
        directoryL1C1_I
      };
      
    ----Backend/Murphi/MurphiModular/Types/GenMachineSets
      -- Cluster: C1
      OBJSET_cacheL1C1: scalarset(3);
      OBJSET_directoryL1C1: enum{directoryL1C1};
      C1Machines: union{OBJSET_cacheL1C1, OBJSET_directoryL1C1};
      
      Machines: union{OBJSET_cacheL1C1, OBJSET_directoryL1C1};
    
    ----Backend/Murphi/MurphiModular/Types/GenCheckTypes
      ------Backend/Murphi/MurphiModular/Types/CheckTypes/GenPermType
        acc_type_obj: multiset[3] of PermissionType;
        PermMonitor: array[Machines] of array[Address] of acc_type_obj;
      
    ----Backend/Murphi/MurphiModular/Types/GenMessage
      Message: record
        adr: Address;
        mtype: MessageType;
        src: Machines;
        dst: Machines;
        cl: ClValue;
        acksExpectedL1C1: 0..NrCachesL1C1;
        corrupted: 0..1; -- If this is 1, then the message is corrupted, otherwise not. 

        -- If we need more stuff for the pings then we can create it here
        -- specific for pings, the others do not need it
        original_req: Machines;
        ping_type: MessageType; -- we can use some of the same message names in here
        -- For exmaple, the abstracted ping name will be PING, but the actual message type can be GetS or GetM underneath it
      end;
    
    -- SanyaSriv: Making a timer status in here:
    Timer: record
      msg: Message; -- the sending of this message started this timer
      msg_in_wait: Message; -- if the node recieves this message, then the timer will end
      timer_in_use: 0..1; -- 0 means that this timer is not in use
      time_elapsed: 0..10; -- After 10 cycles, we will trigger an event
    end;

    ----Backend/Murphi/MurphiModular/Types/GenNetwork
      NET_Ordered: array[Machines] of array[0..O_NET_MAX-1] of Message;
      NET_Ordered_cnt: array[Machines] of 0..O_NET_MAX;
      NET_Unordered: array[Machines] of multiset[U_NET_MAX] of Message;
    
    ----Backend/Murphi/MurphiModular/Types/GenMachines
      
      ENTRY_cacheL1C1: record
        State: s_cacheL1C1;
        cl: ClValue;
        acksReceivedL1C1: 0..NrCachesL1C1;
        acksExpectedL1C1: 0..NrCachesL1C1;
      end;
      
      MACH_cacheL1C1: record
        cb: array[Address] of ENTRY_cacheL1C1;
        timerArray: array[0..O_NET_MAX*3] of Timer;
      end;
      
      OBJ_cacheL1C1: array[OBJSET_cacheL1C1] of MACH_cacheL1C1;
      v_cacheL1C1: multiset[NrCachesL1C1] of Machines;
      cnt_v_cacheL1C1: 0..NrCachesL1C1;
      
      ENTRY_directoryL1C1: record
        State: s_directoryL1C1;
        cl: ClValue;
        cacheL1C1: v_cacheL1C1;
        ownerL1C1: Machines;
      end;
      
      MACH_directoryL1C1: record
        cb: array[Address] of ENTRY_directoryL1C1;
        -- SanySriv: Our assumption is that the directory does not keep track of any timers
        -- So no additional exevnt needs to be added in here
      end;
      
      OBJ_directoryL1C1: array[OBJSET_directoryL1C1] of MACH_directoryL1C1;
    

  var
    --Backend/Murphi/MurphiModular/GenVars
      -- These are the listof successful virtual networks
      fwd: NET_Ordered;
      cnt_fwd: NET_Ordered_cnt;
      resp: NET_Ordered;
      cnt_resp: NET_Ordered_cnt;
      req: NET_Ordered;
      cnt_req: NET_Ordered_cnt;
      ping: NET_Ordered; 
      cnt_ping: NET_Ordered_cnt; -- TOOD (resolved): Add a network for the ping
    
     -- These are the virtual networks for faulty virtual networks
     -- message packets will fail if they choose this virtual network
      fwd_failure: NET_Ordered;
      cnt_fwd_failure: NET_Ordered_cnt;
      resp_failure: NET_Ordered;
      cnt_resp_failure: NET_Ordered_cnt;
      req_failure: NET_Ordered;
      cnt_req_failure: NET_Ordered_cnt;
      ping_failure: NET_Ordered; 
      cnt_ping_failure: NET_Ordered_cnt; 

      g_perm: PermMonitor;
      i_cacheL1C1: OBJ_cacheL1C1;
      i_directoryL1C1: OBJ_directoryL1C1;
  
--Backend/Murphi/MurphiModular/GenFunctions

  ----Backend/Murphi/MurphiModular/Functions/GenResetFunc
    procedure ResetMachine_cacheL1C1();
    begin
      for i:OBJSET_cacheL1C1 do
        for a:Address do
          i_cacheL1C1[i].cb[a].State := cacheL1C1_I;
          i_cacheL1C1[i].cb[a].cl := 0;
          i_cacheL1C1[i].cb[a].acksReceivedL1C1 := 0;
          i_cacheL1C1[i].cb[a].acksExpectedL1C1 := 0;
        endfor;

        -- SanyaSriv: adding code in here to reset the timerArray
        for t:0..O_NET_MAX*3 do
          i_cacheL1C1[i].timerArray[t].timer_in_use := 0;
          i_cacheL1C1[i].timerArray[t].time_elapsed := 0;
        endfor;

      endfor;
    end;
    
    procedure ResetMachine_directoryL1C1();
    begin
      for i:OBJSET_directoryL1C1 do
        for a:Address do
          i_directoryL1C1[i].cb[a].State := directoryL1C1_I;
          i_directoryL1C1[i].cb[a].cl := 0;
          undefine i_directoryL1C1[i].cb[a].cacheL1C1;
          undefine i_directoryL1C1[i].cb[a].ownerL1C1;
    
        endfor;
      endfor;
    end;
    
      procedure ResetMachine_();
      begin
      ResetMachine_cacheL1C1();
      ResetMachine_directoryL1C1();
      
      end;
  ----Backend/Murphi/MurphiModular/Functions/GenEventFunc
  ----Backend/Murphi/MurphiModular/Functions/GenPermFunc
    procedure Clear_perm(adr: Address; m: Machines);
    begin
      alias l_perm_set:g_perm[m][adr] do
          undefine l_perm_set;
      endalias;
    end;
    
    procedure Set_perm(acc_type: PermissionType; adr: Address; m: Machines);
    begin
      alias l_perm_set:g_perm[m][adr] do
      if MultiSetCount(i:l_perm_set, l_perm_set[i] = acc_type) = 0 then
          MultisetAdd(acc_type, l_perm_set);
      endif;
      endalias;
    end;
    
    procedure Reset_perm();
    begin
      for m:Machines do
        for adr:Address do
          Clear_perm(adr, m);
        endfor;
      endfor;
    end;
    
  
  ----Backend/Murphi/MurphiModular/Functions/GenVectorFunc
    -- .add()
    procedure AddElement_cacheL1C1(var sv:v_cacheL1C1; n:Machines);
    begin
        if MultiSetCount(i:sv, sv[i] = n) = 0 then
          MultiSetAdd(n, sv);
        endif;
    end;
    
    -- .del()
    procedure RemoveElement_cacheL1C1(var sv:v_cacheL1C1; n:Machines);
    begin
        if MultiSetCount(i:sv, sv[i] = n) = 1 then
          MultiSetRemovePred(i:sv, sv[i] = n);
        endif;
    end;
    
    -- .clear()
    procedure ClearVector_cacheL1C1(var sv:v_cacheL1C1;);
    begin
        MultiSetRemovePred(i:sv, true);
    end;
    
    -- .contains()
    function IsElement_cacheL1C1(var sv:v_cacheL1C1; n:Machines) : boolean;
    begin
        if MultiSetCount(i:sv, sv[i] = n) = 1 then
          return true;
        elsif MultiSetCount(i:sv, sv[i] = n) = 0 then
          return false;
        else
          Error "Multiple Entries of Sharer in SV multiset";
        endif;
      return false;
    end;
    
    -- .empty()
    function HasElement_cacheL1C1(var sv:v_cacheL1C1; n:Machines) : boolean;
    begin
        if MultiSetCount(i:sv, true) = 0 then
          return false;
        endif;
    
        return true;
    end;
    
    -- .count()
    function VectorCount_cacheL1C1(var sv:v_cacheL1C1) : cnt_v_cacheL1C1;
    begin
        return MultiSetCount(i:sv, true);
    end;
    
  ----Backend/Murphi/MurphiModular/Functions/GenFIFOFunc
  ----Backend/Murphi/MurphiModular/Functions/GenNetworkFunc
    procedure Send_fwd(msg:Message; src: Machines;);
      Assert(cnt_fwd[msg.dst] < O_NET_MAX) "Too many messages";
      fwd[msg.dst][cnt_fwd[msg.dst]] := msg;
      cnt_fwd[msg.dst] := cnt_fwd[msg.dst] + 1;
    end;
    
    procedure Pop_fwd(dst:Machines; src: Machines;);
    begin
      Assert (cnt_fwd[dst] > 0) "Trying to advance empty Q";
      for i := 0 to cnt_fwd[dst]-1 do
        if i < cnt_fwd[dst]-1 then
          fwd[dst][i] := fwd[dst][i+1];
        else
          undefine fwd[dst][i];
        endif;
      endfor;
      cnt_fwd[dst] := cnt_fwd[dst] - 1;
    end;
    
    procedure Send_resp(msg:Message; src: Machines;);
      Assert(cnt_resp[msg.dst] < O_NET_MAX) "Too many messages";
      resp[msg.dst][cnt_resp[msg.dst]] := msg;
      cnt_resp[msg.dst] := cnt_resp[msg.dst] + 1;
    end;
    
    procedure Pop_resp(dst:Machines; src: Machines;);
    begin
      Assert (cnt_resp[dst] > 0) "Trying to advance empty Q";
      for i := 0 to cnt_resp[dst]-1 do
        if i < cnt_resp[dst]-1 then
          resp[dst][i] := resp[dst][i+1];
        else
          undefine resp[dst][i];
        endif;
      endfor;
      cnt_resp[dst] := cnt_resp[dst] - 1;
    end;
    
    procedure Send_req(msg:Message; src: Machines;);
      Assert(cnt_req[msg.dst] < O_NET_MAX) "Too many messages";
      req[msg.dst][cnt_req[msg.dst]] := msg;
      cnt_req[msg.dst] := cnt_req[msg.dst] + 1;
    end;
    
    procedure Pop_req(dst:Machines; src: Machines;);
    begin
      Assert (cnt_req[dst] > 0) "Trying to advance empty Q";
      for i := 0 to cnt_req[dst]-1 do
        if i < cnt_req[dst]-1 then
          req[dst][i] := req[dst][i+1];
        else
          undefine req[dst][i];
        endif;
      endfor;
      cnt_req[dst] := cnt_req[dst] - 1;
    end;

    -- TOOD (resolved): Add pop and push for pings
    -- pings will never be multicast, and will always be unicast

    procedure Send_ping(msg:Message;);
      Assert(cnt_ping[msg.dst] < O_NET_MAX) "Too many messages";
      ping[msg.dst][cnt_ping[msg.dst]] := msg;
      cnt_ping[msg.dst] := cnt_ping[msg.dst] + 1;
    end;
    
    procedure Pop_ping(dst:Machines; src: Machines;);
    begin
      Assert (cnt_ping[dst] > 0) "Trying to advance empty Q";
      for i := 0 to cnt_ping[dst]-1 do
        if i < cnt_ping[dst]-1 then
          ping[dst][i] := ping[dst][i+1];
        else
          undefine ping[dst][i];
        endif;
      endfor;
      cnt_ping[dst] := cnt_ping[dst] - 1;
    end;

   -- TODO (SanyaSriv): Adding procedures here to push stuff to a failed VC
   -- everything inside this VC will fail
   
   procedure Send_fwd_failure(msg:Message; src: Machines;);
      Assert(cnt_fwd_failure[msg.dst] < O_NET_MAX) "Too many messages";
      fwd_failure[msg.dst][cnt_fwd_failure[msg.dst]] := msg;
      cnt_fwd_failure[msg.dst] := cnt_fwd_failure[msg.dst] + 1;
    end;
    
    procedure Pop_fwd_failure(dst:Machines; src: Machines;);
    begin
      Assert (cnt_fwd_failure[dst] > 0) "Trying to advance empty Q";
      for i := 0 to cnt_fwd_failure[dst]-1 do
        if i < cnt_fwd_failure[dst]-1 then
          fwd_failure[dst][i] := fwd_failure[dst][i+1];
        else
          undefine fwd_failure[dst][i];
        endif;
      endfor;
      cnt_fwd_failure[dst] := cnt_fwd_failure[dst] - 1;
    end;
    
    procedure Send_resp_failure(msg:Message; src: Machines;);
      Assert(cnt_resp_failure[msg.dst] < O_NET_MAX) "Too many messages";
      resp_failure[msg.dst][cnt_resp_failure[msg.dst]] := msg;
      cnt_resp_failure[msg.dst] := cnt_resp_failure[msg.dst] + 1;
    end;
    
    procedure Pop_resp_failure(dst:Machines; src: Machines;);
    begin
      Assert (cnt_resp_failure[dst] > 0) "Trying to advance empty Q";
      for i := 0 to cnt_resp_failure[dst]-1 do
        if i < cnt_resp_failure[dst]-1 then
          resp_failure[dst][i] := resp_failure[dst][i+1];
        else
          undefine resp_failure[dst][i];
        endif;
      endfor;
      cnt_resp_failure[dst] := cnt_resp_failure[dst] - 1;
    end;
    
    procedure Send_req_failure(msg:Message; src: Machines;);
      Assert(cnt_req_failure[msg.dst] < O_NET_MAX) "Too many messages";
      req_failure[msg.dst][cnt_req_failure[msg.dst]] := msg;
      cnt_req_failure[msg.dst] := cnt_req_failure[msg.dst] + 1;
    end;
    
    procedure Pop_req_failure(dst:Machines; src: Machines;);
    begin
      Assert (cnt_req_failure[dst] > 0) "Trying to advance empty Q";
      for i := 0 to cnt_req_failure[dst]-1 do
        if i < cnt_req_failure[dst]-1 then
          req_failure[dst][i] := req_failure[dst][i+1];
        else
          undefine req_failure[dst][i];
        endif;
      endfor;
      cnt_req_failure[dst] := cnt_req_failure[dst] - 1;
    end;

    procedure Send_ping_failure(msg:Message; src: Machines;);
      Assert(cnt_ping_failure[msg.dst] < O_NET_MAX) "Too many messages";
      ping_failure[msg.dst][cnt_ping_failure[msg.dst]] := msg;
      cnt_ping_failure[msg.dst] := cnt_ping_failure[msg.dst] + 1;
    end;
    
    procedure Pop_ping_filure(dst:Machines; src: Machines;);
    begin
      Assert (cnt_ping_failure[dst] > 0) "Trying to advance empty Q";
      for i := 0 to cnt_ping_failure[dst]-1 do
        if i < cnt_ping_failure[dst]-1 then
          ping_failure[dst][i] := ping_failure[dst][i+1];
        else
          undefine ping_failure[dst][i];
        endif;
      endfor;
      cnt_ping_failure[dst] := cnt_ping_failure[dst] - 1;
    end;
    
    procedure Multicast_fwd_v_cacheL1C1(var msg: Message; dst_vect: v_cacheL1C1; src: Machines;);
    begin
          for n:Machines do
              if n!=msg.src then
                if MultiSetCount(i:dst_vect, dst_vect[i] = n) = 1 then
                  msg.dst := n;
                  Send_fwd(msg, src);
                endif;
              endif;
          endfor;
    end;
    
    function resp_network_ready(): boolean;
    begin
          for dst:Machines do
            for src: Machines do
              if cnt_resp[dst] >= (O_NET_MAX-4) then
                return false;
              endif;
            endfor;
          endfor;
    
          return true;
    end;
    function fwd_network_ready(): boolean;
    begin
          for dst:Machines do
            for src: Machines do
              if cnt_fwd[dst] >= (O_NET_MAX-4) then
                return false;
              endif;
            endfor;
          endfor;
    
          return true;
    end;
    function req_network_ready(): boolean;
    begin
          for dst:Machines do
            for src: Machines do
              if cnt_req[dst] >= (O_NET_MAX-4) then
                return false;
              endif;
            endfor;
          endfor;
    
          return true;
    end;

    function ping_network_ready(): boolean;
    begin
          for dst:Machines do
            for src: Machines do
              if cnt_ping[dst] >= (O_NET_MAX-4) then
                return false;
              endif;
            endfor;
          endfor;
    
          return true;
    end;

    function network_ready(): boolean;
    begin
            if !resp_network_ready() then
            return false;
          endif;
    
    
          if !fwd_network_ready() then
            return false;
          endif;
    
    
          if !req_network_ready() then
            return false;
          endif;

          -- Adding init for ping
          if !ping_network_ready() then
            return false;
          endif;
    
      return true;
    end;
    
    procedure Reset_NET_();
    begin
      
      undefine fwd;
      for dst:Machines do
          cnt_fwd[dst] := 0;
      endfor;
      
      undefine resp;
      for dst:Machines do
          cnt_resp[dst] := 0;
      endfor;
      
      undefine req;
      for dst:Machines do
          cnt_req[dst] := 0;
      endfor;

      -- adding the same init for ping
      undefine ping;
      for dst:Machines do
          cnt_ping[dst] := 0;
      endfor;

    end;
    
  
  ----Backend/Murphi/MurphiModular/Functions/GenMessageConstrFunc
    -- TOOD: construct a ping message in here
    -- Sanya Methodology suggestion --> instead of building a while unsafe network, we can just send this message with a 1 bit value
    -- that specifies whetehr it has failed or not
    -- if the 1 bit value is set, then consider it failed
    -- otherwise, we can continue to process it

    function MakePing(timer: Timer; corrupted:0..1) : Message;
    var Message: Message; -- ping packet
    begin
      Message.adr := timer.msg.adr;
      Message.mtype := PING;
      Message.src := timer.msg.src;
      Message.dst := timer.msg.dst;
      Message.corrupted := corrupted;
      -- SanyaSriv: this is useful in case of ping propagation. This field should never change if the ping is getting propagated. 
      -- this indicates the original requestor that started/initiated this ping. 
      Message.original_req := timer.msg.src; 
      Message.ping_type := timer.msg.mtype;
    return Message;
    end;    

    function MakePingProp(adr: Address; mtype: MessageType; src: Machines; original_req: Machines; dst: Machines; corrupted:0..1) : Message;
    var Message: Message; -- ping packet
    begin
      Message.adr := adr;
      Message.mtype := PING_PROP;
      Message.src := src;
      Message.dst := dst;
      Message.corrupted := corrupted;
      -- SanyaSriv: this is useful in case of ping propagation. This field should never change if the ping is getting propagated. 
      -- this indicates the original requestor that started/initiated this ping. 
      Message.original_req := original_req; 
      Message.ping_type := mtype;
    return Message;
    end;

    function MakePingResp(original_ping: Message; typem: MessageType; cl: ClValue; corrupted:0..1) : Message;
    var Message: Message;
    begin
      Message.adr := original_ping.adr;
      Message.mtype := typem;
      Message.src := original_ping.dst;
      Message.dst := original_ping.src;
      Message.corrupted := corrupted;
      Message.original_req := original_ping.src;
      Message.ping_type := original_ping.ping_type;
      Message.cl := cl; -- optional data attachment in case the message was an ACK_SUCCESS

    return Message
    end;

    function RequestL1C1(adr: Address; mtype: MessageType; src: Machines; dst: Machines; corrupted:0..1) : Message;
    var Message: Message;
    begin
      Message.adr := adr;
      Message.mtype := mtype;
      Message.src := src;
      Message.dst := dst;
      Message.corrupted := corrupted;
    return Message;
    end;
    
    function AckL1C1(adr: Address; mtype: MessageType; src: Machines; dst: Machines; corrupted:0..1) : Message;
    var Message: Message;
    begin
      Message.adr := adr;
      Message.mtype := mtype;
      Message.src := src;
      Message.dst := dst;
      Message.corrupted := corrupted;
    return Message;
    end;
    
    function RespL1C1(adr: Address; mtype: MessageType; src: Machines; dst: Machines; cl: ClValue; corrupted:0..1) : Message;
    var Message: Message;
    begin
      Message.adr := adr;
      Message.mtype := mtype;
      Message.src := src;
      Message.dst := dst;
      Message.cl := cl;
      Message.corrupted := corrupted;
    return Message;
    end;
    
    function RespAckL1C1(adr: Address; mtype: MessageType; src: Machines; dst: Machines; cl: ClValue; acksExpectedL1C1: 0..NrCachesL1C1; corrupted:0..1) : Message;
    var Message: Message;
    begin
      Message.adr := adr;
      Message.mtype := mtype;
      Message.src := src;
      Message.dst := dst;
      Message.cl := cl;
      Message.acksExpectedL1C1 := acksExpectedL1C1;
      Message.corrupted := corrupted;
    return Message;
    end;
    
  
  -- SanyaSriv: Adding a procedure here to start the timer
  procedure StartTimer(msg: Message; msg_needed: Message; i: OBJSET_cacheL1C1);
    -- try to find an empty spot in the timer array and init it
    begin
      for t:0..O_NET_MAX*3 do
        if i_cacheL1C1[i].timerArray[t].timer_in_use = 0 then
          -- instantiate the timer here
          i_cacheL1C1[i].timerArray[t].time_elapsed := 0;
          i_cacheL1C1[i].timerArray[t].msg := msg;
          i_cacheL1C1[i].timerArray[t].msg_in_wait := msg_needed;
          i_cacheL1C1[i].timerArray[t].timer_in_use := 1;
          return;
        endif;
        -- SanyaSriv TODO: What happens when we dont have anymore available timers?
      endfor;
  end;

  -- SanyaSriv: Adding a procedure here to end the timer
  procedure EndTimer(msg: Message; i: OBJSET_cacheL1C1);
  begin
      for t:0..O_NET_MAX*3 do
        if i_cacheL1C1[i].timerArray[t].timer_in_use = 1 then
          -- check if this timer was waiting for the message that just got in
          if (i_cacheL1C1[i].timerArray[t].msg_in_wait.adr = msg.adr) & 
              (i_cacheL1C1[i].timerArray[t].msg_in_wait.mtype = msg.mtype) &
              (i_cacheL1C1[i].timerArray[t].msg_in_wait.src = msg.src) then
                -- remove the timer
                i_cacheL1C1[i].timerArray[t].timer_in_use := 0;
                i_cacheL1C1[i].timerArray[t].time_elapsed := 0;
                return;
          endif;
        endif;
      endfor;
  end;

-- SanyaSriv: Adding a procedure here to increment the tick counter of everything
procedure Tick();
  var msg : Message;
  begin
    for i:OBJSET_cacheL1C1 do
      for t:0..O_NET_MAX*3 do
        if i_cacheL1C1[i].timerArray[t].timer_in_use = 1 then
          -- if the timer is active then increment the tick
          i_cacheL1C1[i].timerArray[t].time_elapsed := i_cacheL1C1[i].timerArray[t].time_elapsed + 1;
          -- if the tick becomes 10, then initiate a timeout event
          if i_cacheL1C1[i].timerArray[t].time_elapsed = 5 then -- TIMEOUT HAS HAPPENED + SEND A PING
            msg := MakePing(i_cacheL1C1[i].timerArray[t], 0); -- not setting the corruption bit for now, but we can do it while testing
            if ping_network_ready() then
              Send_ping(msg); -- SanyaSriv: can optionally add in here a check to make sure that the ping network is ready; add this if things fail during checks. 
              -- reset the timer
              i_cacheL1C1[i].timerArray[t].time_elapsed := 0;
            endif;
          endif;
        endif;
      endfor;
    endfor;
  end;

--Backend/Murphi/MurphiModular/GenStateMachines

  ----Backend/Murphi/MurphiModular/StateMachines/GenAccessStateMachines
    procedure FSM_Access_cacheL1C1_I_load(adr:Address; m:OBJSET_cacheL1C1);
    var msg: Message;
    var msg_expected : Message;
    begin
    alias cbe: i_cacheL1C1[m].cb[adr] do
      msg := RequestL1C1(adr, GetSL1C1, m, directoryL1C1, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
      Send_req(msg, m);
      -- start the timer in here for this message
      msg_expected := RespL1C1(adr,GetS_AckL1C1, directoryL1C1, m, 0, 0);
      StartTimer(msg, msg_expected, m);
      cbe.State := cacheL1C1_I_load;
    endalias;
    end;
    
    procedure FSM_Access_cacheL1C1_I_store(adr:Address; m:OBJSET_cacheL1C1);
    var msg: Message;
    begin
    alias cbe: i_cacheL1C1[m].cb[adr] do
      msg := RequestL1C1(adr, GetML1C1, m, directoryL1C1, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
      Send_req(msg, m);
      cbe.acksReceivedL1C1 := 0;
      cbe.State := cacheL1C1_I_store;
    endalias;
    end;
    
    procedure FSM_Access_cacheL1C1_M_evict(adr:Address; m:OBJSET_cacheL1C1);
    var msg: Message;
    begin
    alias cbe: i_cacheL1C1[m].cb[adr] do
      msg := RespL1C1(adr, PutML1C1, m, directoryL1C1, cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
      Send_req(msg, m);
      cbe.State := cacheL1C1_M_evict;
    endalias;
    end;
    
    procedure FSM_Access_cacheL1C1_M_load(adr:Address; m:OBJSET_cacheL1C1);
    begin
    alias cbe: i_cacheL1C1[m].cb[adr] do
      Set_perm(load, adr, m);cbe.State := cacheL1C1_M;
    endalias;
    end;
    
    procedure FSM_Access_cacheL1C1_M_store(adr:Address; m:OBJSET_cacheL1C1);
    begin
    alias cbe: i_cacheL1C1[m].cb[adr] do
      Set_perm(store, adr, m);cbe.State := cacheL1C1_M;
    endalias;
    end;
    
    procedure FSM_Access_cacheL1C1_S_evict(adr:Address; m:OBJSET_cacheL1C1);
    var msg: Message;
    begin
    alias cbe: i_cacheL1C1[m].cb[adr] do
      msg := RequestL1C1(adr, PutSL1C1, m, directoryL1C1, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
      Send_req(msg, m);
      cbe.State := cacheL1C1_S_evict;
    endalias;
    end;
    
    procedure FSM_Access_cacheL1C1_S_load(adr:Address; m:OBJSET_cacheL1C1);
    begin
    alias cbe: i_cacheL1C1[m].cb[adr] do
      Set_perm(load, adr, m);
      cbe.State := cacheL1C1_S;
    endalias;
    end;
    
    procedure FSM_Access_cacheL1C1_S_store(adr:Address; m:OBJSET_cacheL1C1);
    var msg: Message;
    begin
    alias cbe: i_cacheL1C1[m].cb[adr] do
      msg := RequestL1C1(adr, GetML1C1, m, directoryL1C1, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
      Send_req(msg, m);
      cbe.acksReceivedL1C1 := 0;
      cbe.State := cacheL1C1_S_store;
    endalias;
    end;
  

  ----Backend/Murphi/MurphiModular/StateMachines/GenMessageStateMachines
    function FSM_MSG_cacheL1C1(inmsg:Message; m:OBJSET_cacheL1C1; corruption:0..1) : boolean;
    var msg: Message;
    begin
      alias adr: inmsg.adr do
      alias cbe: i_cacheL1C1[m].cb[adr] do
      -- SanyaSriv: drop the message if it is corrupted
      if inmsg.corrupted = 1 then
        return true;
      endif;
      
    switch cbe.State
      case cacheL1C1_I:
      switch inmsg.mtype
      endswitch;
      -- TODO: Add case for pings

      case cacheL1C1_I_load:
      switch inmsg.mtype
        case GetS_AckL1C1:
          cbe.cl := inmsg.cl;
          Set_perm(load, adr, m);
          Clear_perm(adr, m); Set_perm(load, adr, m);
          cbe.State := cacheL1C1_S;
          EndTimer(inmsg, m); -- end the timer here 
          return true;

        case ACK_PING_FAILURE: -- I TO S CASE
          switch inmsg.ping_type
            case GetSL1C1:
              -- just send this message again
              msg := RequestL1C1(adr, GetSL1C1, m, directoryL1C1, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
              Send_req(msg, m); -- we can reuse the original message timer for this event so no need to create a new one
              cbe.State := cacheL1C1_I_load;
              return true;
            else return false;
          endswitch;

        case ACK_PING_SUCCESS:
          switch inmsg.ping_type
            case GetSL1C1: 
              -- this means that the directory processed the message, but the response probably failed somewhere
              -- but if this is the case, then the directory would have appended the response packet
              -- so extract the response, and get to the correct state. 
              cbe.cl := inmsg.cl;
              Set_perm(load, adr, m);
              Clear_perm(adr, m); Set_perm(load, adr, m);
              cbe.State := cacheL1C1_S;
              return true;
            else return false;
          endswitch;
        
        else return false;
      endswitch;
      
      case cacheL1C1_I_store:
      switch inmsg.mtype
        case GetM_Ack_ADL1C1:
          cbe.cl := inmsg.cl;
          cbe.acksExpectedL1C1 := inmsg.acksExpectedL1C1;
          if !(cbe.acksExpectedL1C1 = cbe.acksReceivedL1C1) then
            Clear_perm(adr, m);
            cbe.State := cacheL1C1_I_store_GetM_Ack_AD;
            return true;
          endif;
          if (cbe.acksExpectedL1C1 = cbe.acksReceivedL1C1) then
            Set_perm(store, adr, m);
            Clear_perm(adr, m); Set_perm(store, adr, m); Set_perm(load, adr, m);
            cbe.State := cacheL1C1_M;
            return true;
          endif;
        
        case GetM_Ack_DL1C1:
          cbe.cl := inmsg.cl;
          Set_perm(store, adr, m);
          Clear_perm(adr, m); Set_perm(store, adr, m); Set_perm(load, adr, m);
          cbe.State := cacheL1C1_M;
          return true;
        
        case Inv_AckL1C1:
          cbe.acksReceivedL1C1 := cbe.acksReceivedL1C1+1;
          Clear_perm(adr, m);
          cbe.State := cacheL1C1_I_store;
          return true;
        
        else return false;
      endswitch;
      
      case cacheL1C1_I_store_GetM_Ack_AD:
      switch inmsg.mtype
        case Inv_AckL1C1:
          cbe.acksReceivedL1C1 := cbe.acksReceivedL1C1+1;
          if !(cbe.acksExpectedL1C1 = cbe.acksReceivedL1C1) then
            Clear_perm(adr, m);
            cbe.State := cacheL1C1_I_store_GetM_Ack_AD;
            return true;
          endif;
          if (cbe.acksExpectedL1C1 = cbe.acksReceivedL1C1) then
            Set_perm(store, adr, m);
            Clear_perm(adr, m); Set_perm(store, adr, m); Set_perm(load, adr, m);
            cbe.State := cacheL1C1_M;
            return true;
          endif;
        
        else return false;
      endswitch;
      
      case cacheL1C1_M:
      switch inmsg.mtype
        case Fwd_GetML1C1:
          msg := RespL1C1(adr,GetM_Ack_DL1C1,m,inmsg.src,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the corruption variable
          Send_resp(msg, m);
          Clear_perm(adr, m);
          cbe.State := cacheL1C1_I;
          return true;
        
        case Fwd_GetSL1C1:
          msg := RespL1C1(adr,GetS_AckL1C1,m,inmsg.src,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the corruption variable
          Send_resp(msg, m);
          msg := RespL1C1(adr,WBL1C1,m,directoryL1C1,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the corruption variable
          Send_resp(msg, m);
          Clear_perm(adr, m); Set_perm(load, adr, m);
          cbe.State := cacheL1C1_S;
          return true;
        
        else return false;
      endswitch;
      
      case cacheL1C1_M_evict:
      switch inmsg.mtype
        case Fwd_GetML1C1:
          msg := RespL1C1(adr,GetM_Ack_DL1C1,m,inmsg.src,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the corruption variable
          Send_resp(msg, m);
          Clear_perm(adr, m);
          cbe.State := cacheL1C1_M_evict_x_I;
          return true;
        
        case Fwd_GetSL1C1:
          msg := RespL1C1(adr,GetS_AckL1C1,m,inmsg.src,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the corruption variable
          Send_resp(msg, m);
          msg := RespL1C1(adr,WBL1C1,m,directoryL1C1,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the corruption variable
          Send_resp(msg, m);
          Clear_perm(adr, m);
          cbe.State := cacheL1C1_S_evict;
          return true;
        
        case Put_AckL1C1:
          Clear_perm(adr, m);
          cbe.State := cacheL1C1_I;
          return true;
        
        else return false;
      endswitch;
      
      case cacheL1C1_M_evict_x_I:
      switch inmsg.mtype
        case Put_AckL1C1:
          Clear_perm(adr, m);
          cbe.State := cacheL1C1_I;
          return true;
        
        else return false;
      endswitch;
      
      case cacheL1C1_S:
      switch inmsg.mtype
        case InvL1C1:
          msg := RespL1C1(adr,Inv_AckL1C1,m,inmsg.src,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the corruption variable
          Send_resp(msg, m);
          Clear_perm(adr, m);
          cbe.State := cacheL1C1_I;
          return true;
        
        case GetS_AckL1C1: -- This is when we got ping response before data
          -- drop this, because if we transitioned to this state, then it probably happened because of the ping
           return true; -- this is synonymous to dropping the message and not processing it further
        
        case ACK_PING_SUCCESS: -- this is when we got data before ping response - timeout happened but no failure was there
          -- drop this, because if we transitioned to this state, then it probably happened because of the ping
          return true; -- this is synonymous to dropping the message and not processing it further

        else return false;
      endswitch;
      
      case cacheL1C1_S_evict:
      switch inmsg.mtype
        case InvL1C1:
          msg := RespL1C1(adr,Inv_AckL1C1,m,inmsg.src,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the corruption variable
          Send_resp(msg, m);
          Clear_perm(adr, m);
          cbe.State := cacheL1C1_S_evict_x_I;
          return true;
        
        case Put_AckL1C1:
          Clear_perm(adr, m);
          cbe.State := cacheL1C1_I;
          return true;
        
        else return false;
      endswitch;
      
      case cacheL1C1_S_evict_x_I:
      switch inmsg.mtype
        case Put_AckL1C1:
          Clear_perm(adr, m);
          cbe.State := cacheL1C1_I;
          return true;
        
        else return false;
      endswitch;
      
      case cacheL1C1_S_store:
      switch inmsg.mtype
        case GetM_Ack_ADL1C1:
          cbe.acksExpectedL1C1 := inmsg.acksExpectedL1C1;
          if (cbe.acksExpectedL1C1 = cbe.acksReceivedL1C1) then
            Set_perm(store, adr, m);
            Clear_perm(adr, m); Set_perm(store, adr, m); Set_perm(load, adr, m);
            cbe.State := cacheL1C1_M;
            return true;
          endif;
          if !(cbe.acksExpectedL1C1 = cbe.acksReceivedL1C1) then
            Clear_perm(adr, m);
            cbe.State := cacheL1C1_S_store_GetM_Ack_AD;
            return true;
          endif;
        
        case GetM_Ack_DL1C1:
          Set_perm(store, adr, m);
          Clear_perm(adr, m); Set_perm(store, adr, m); Set_perm(load, adr, m);
          cbe.State := cacheL1C1_M;
          return true;
        
        case InvL1C1:
          msg := RespL1C1(adr,Inv_AckL1C1,m,inmsg.src,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the corruption variable
          Send_resp(msg, m);
          Clear_perm(adr, m);
          cbe.State := cacheL1C1_I_store;
          return true;
        
        case Inv_AckL1C1:
          cbe.acksReceivedL1C1 := cbe.acksReceivedL1C1+1;
          Clear_perm(adr, m);
          cbe.State := cacheL1C1_S_store;
          return true;
        
        else return false;
      endswitch;
      
      case cacheL1C1_S_store_GetM_Ack_AD:
      switch inmsg.mtype
        case Inv_AckL1C1:
          cbe.acksReceivedL1C1 := cbe.acksReceivedL1C1+1;
          if (cbe.acksExpectedL1C1 = cbe.acksReceivedL1C1) then
            Set_perm(store, adr, m);
            Clear_perm(adr, m); Set_perm(store, adr, m); Set_perm(load, adr, m);
            cbe.State := cacheL1C1_M;
            return true;
          endif;
          if !(cbe.acksExpectedL1C1 = cbe.acksReceivedL1C1) then
            Clear_perm(adr, m);
            cbe.State := cacheL1C1_S_store_GetM_Ack_AD;
            return true;
          endif;
        
        else return false;
      endswitch;
      
    endswitch;
    endalias;
    endalias;
    return false;
    end;
    
    function FSM_MSG_directoryL1C1(inmsg:Message; m:OBJSET_directoryL1C1; corruption:0..1) : boolean;
    var msg: Message;
    begin
      alias adr: inmsg.adr do
      alias cbe: i_directoryL1C1[m].cb[adr] do
      if inmsg.corrupted = 1 then
        return true;
      endif;
    switch cbe.State
      case directoryL1C1_I:
      switch inmsg.mtype
        case GetML1C1:
          msg := RespL1C1(adr,GetM_Ack_DL1C1,m,inmsg.src,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
          Send_resp(msg, m);
          cbe.ownerL1C1 := inmsg.src;
          Clear_perm(adr, m);
          cbe.State := directoryL1C1_M;
          return true;
        
        case PING:
          -- adding case to specifically handle failures in GetSL1C1 messages when the directory was originally in state I
          switch inmsg.ping_type
            case GetSL1C1:
              -- if the directory sees a ping for a GetSL1C1 in this stage, then it means it probably never reached the directory
              -- otherwise it would have transitioned to some other state
              -- So, this means that the original GetSL1C1 failed, so send a ping failed ACK.
              msg := MakePingResp(inmsg, ACK_PING_FAILURE, cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
              Send_ping(msg);

            --KG
            case GetML1C1:
              -- if the directory sees a ping for a GetML1C1 in this stage (I), then it means it probably never reached the directory
              -- otherwise it would have transitioned from I --> M
              -- means that the original GetML1C1 failed, so send a ping failed ACK
              msg := MakePingResp(inmsg, ACK_PING_FAILURE, cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
              Send_ping(msg);

            --KG: since a Put-Ack was supposed to be sent (not data), should this be handled differently?
            case PutML1C1:
              -- if the directory sees a ping for a PutML1C1 in this stage (I), then it means the request reached, and the Put-Ack got corrupted
              -- so just send a success ACK 
              msg := MakePingResp(inmsg, ACK_PING_SUCCESS, cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
              Send_ping(msg);

            --KG: since a Put-Ack was supposed to be sent (not data), should this be handled differently?
            case PutSL1C1:
              -- if the directory sees a ping for a PutSL1C1 in this stage (I), then it means the request reached, and the data got corrupted
              -- so just send a success ACK and append the data to it 
              msg := MakePingResp(inmsg, ACK_PING_SUCCESS, cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
              Send_ping(msg);
          endswitch;

        case GetSL1C1:
          AddElement_cacheL1C1(cbe.cacheL1C1, inmsg.src);
          msg := RespL1C1(adr,GetS_AckL1C1,m,inmsg.src,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
          Send_resp(msg, m);
          Clear_perm(adr, m);
          cbe.State := directoryL1C1_S;
          return true;
        
        case PutML1C1:
          msg := AckL1C1(adr,Put_AckL1C1,m,inmsg.src, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
          Send_fwd(msg, m);
          if !(cbe.ownerL1C1 = inmsg.src) then
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_I;
            return true;
          endif;
          if (cbe.ownerL1C1 = inmsg.src) then
            cbe.cl := inmsg.cl;
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_I;
            return true;
          endif;
        
        case PutSL1C1:
          msg := AckL1C1(adr,Put_AckL1C1,m,inmsg.src, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
          Send_fwd(msg, m);
          RemoveElement_cacheL1C1(cbe.cacheL1C1, inmsg.src);
          if (VectorCount_cacheL1C1(cbe.cacheL1C1) = 0) then
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_I;
            return true;
          endif;
          if !(VectorCount_cacheL1C1(cbe.cacheL1C1) = 0) then
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_I;
            return true;
          endif;
        
        else return false;
      endswitch;
      
      case directoryL1C1_M:
      switch inmsg.mtype
        case GetML1C1:
          msg := RequestL1C1(adr,Fwd_GetML1C1,inmsg.src,cbe.ownerL1C1, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
          Send_fwd(msg, m);
          cbe.ownerL1C1 := inmsg.src;
          Clear_perm(adr, m);
          cbe.State := directoryL1C1_M;
          return true;
        
        --KG
        case PING:
          -- adding case to specifically handle failures in GetML1C1 messages when the directory was originally in state I
          switch inmsg.ping_type
            -- KG: should we worry about handling GetM_Ack_ADL1C1 in this case?
            case GetML1C1:
              -- if the directory sees a ping for a GetML1C1 in this stage (M), then it means the request reached, and the data got corrupted
              -- so just send a success ACK and append the data to it 
              msg := MakePingResp(inmsg, ACK_PING_SUCCESS, cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
              Send_ping(msg);

            case PutML1C1:
              -- if the directory sees a ping for a PutML1C1 in this stage (M), then it means it probably never reached the directory
              -- otherwise it would have transitioned to some other state (I)
              -- So, this means that the original PutML1C1 failed, so send a ping failed ACK
              msg := MakePingResp(inmsg, ACK_PING_FAILURE, cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
              Send_ping(msg);
          endswitch;
        
        case GetSL1C1:
          msg := RequestL1C1(adr,Fwd_GetSL1C1,inmsg.src,cbe.ownerL1C1, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
          Send_fwd(msg, m);
          AddElement_cacheL1C1(cbe.cacheL1C1, inmsg.src);
          AddElement_cacheL1C1(cbe.cacheL1C1, cbe.ownerL1C1);
          Clear_perm(adr, m);
          cbe.State := directoryL1C1_M_GetS;
          return true;
        
        case PutML1C1:
          msg := AckL1C1(adr,Put_AckL1C1,m,inmsg.src, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
          Send_fwd(msg, m);
          if (cbe.ownerL1C1 = inmsg.src) then
            cbe.cl := inmsg.cl;
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_I;
            return true;
          endif;
          if !(cbe.ownerL1C1 = inmsg.src) then
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_M;
            return true;
          endif;
        
        case PutSL1C1:
          msg := AckL1C1(adr,Put_AckL1C1,m,inmsg.src, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
          Send_fwd(msg, m);
          if !(cbe.ownerL1C1 = inmsg.src) then
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_M;
            return true;
          endif;
          if (cbe.ownerL1C1 = inmsg.src) then
            cbe.cl := inmsg.cl;
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_I;
            return true;
          endif;
        
        else return false;
      endswitch;
      
      case directoryL1C1_M_GetS:
      switch inmsg.mtype
        case WBL1C1:
          if !(inmsg.src = cbe.ownerL1C1) then
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_M_GetS;
            return true;
          endif;
          if (inmsg.src = cbe.ownerL1C1) then
            cbe.cl := inmsg.cl;
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_S;
            return true;
          endif;
        
        else return false;
      endswitch;
      
      case directoryL1C1_S:
      switch inmsg.mtype
        case PING:
          -- adding case to specifically handle failures in GetSL1C1 messages when the directory was originally in state I
          switch inmsg.ping_type
            case GetSL1C1:
              -- if the directory sees a ping for a GetSL1C1 in this stage, then it means the request reached, and the data got corrupted
              -- so just send a success ACK and append the data to it 
              msg := MakePingResp(inmsg, ACK_PING_SUCCESS, cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
              Send_ping(msg);
          
            --KG
            case PutSL1C1:
              -- if the directory sees a ping for a PutSL1C1 in this stage (S), then it means it probably never reached the directory
              -- otherwise it would have transitioned to some other state (I)
              -- means that the original PutSL1C1 failed, so send a ping failed ACK
              msg := MakePingResp(inmsg, ACK_PING_FAILURE, cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later to use the variable corruption
              Send_ping(msg);
          endswitch;


        case GetML1C1:
          if (IsElement_cacheL1C1(cbe.cacheL1C1, inmsg.src)) then
            RemoveElement_cacheL1C1(cbe.cacheL1C1, inmsg.src);
            if !(VectorCount_cacheL1C1(cbe.cacheL1C1) = 0) then
              msg := RespAckL1C1(adr,GetM_Ack_ADL1C1,m,inmsg.src,cbe.cl,VectorCount_cacheL1C1(cbe.cacheL1C1), 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
              Send_resp(msg, m);
              msg := AckL1C1(adr,InvL1C1,inmsg.src,inmsg.src, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
              Multicast_fwd_v_cacheL1C1(msg, cbe.cacheL1C1, m);
              cbe.ownerL1C1 := inmsg.src;
              ClearVector_cacheL1C1(cbe.cacheL1C1);
              Clear_perm(adr, m);
              cbe.State := directoryL1C1_M;
              return true;
            endif;
            if (VectorCount_cacheL1C1(cbe.cacheL1C1) = 0) then
              msg := RespL1C1(adr,GetM_Ack_DL1C1,m,inmsg.src,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
              Send_resp(msg, m);
              cbe.ownerL1C1 := inmsg.src;
              ClearVector_cacheL1C1(cbe.cacheL1C1);
              Clear_perm(adr, m);
              cbe.State := directoryL1C1_M;
              return true;
            endif;
          endif;
          if !(IsElement_cacheL1C1(cbe.cacheL1C1, inmsg.src)) then
            if (VectorCount_cacheL1C1(cbe.cacheL1C1) = 0) then
              msg := RespL1C1(adr,GetM_Ack_DL1C1,m,inmsg.src,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
              Send_resp(msg, m);
              cbe.ownerL1C1 := inmsg.src;
              ClearVector_cacheL1C1(cbe.cacheL1C1);
              Clear_perm(adr, m);
              cbe.State := directoryL1C1_M;
              return true;
            endif;
            if !(VectorCount_cacheL1C1(cbe.cacheL1C1) = 0) then
              msg := RespAckL1C1(adr,GetM_Ack_ADL1C1,m,inmsg.src,cbe.cl,VectorCount_cacheL1C1(cbe.cacheL1C1), 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
              Send_resp(msg, m);
              msg := AckL1C1(adr,InvL1C1,inmsg.src,inmsg.src, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
              Multicast_fwd_v_cacheL1C1(msg, cbe.cacheL1C1, m);
              cbe.ownerL1C1 := inmsg.src;
              ClearVector_cacheL1C1(cbe.cacheL1C1);
              Clear_perm(adr, m);
              cbe.State := directoryL1C1_M;
              return true;
            endif;
          endif;
        
        case GetSL1C1:
          AddElement_cacheL1C1(cbe.cacheL1C1, inmsg.src);
          msg := RespL1C1(adr,GetS_AckL1C1,m,inmsg.src,cbe.cl, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
          Send_resp(msg, m);
          Clear_perm(adr, m);
          cbe.State := directoryL1C1_S;
          return true;
        
        case PutML1C1:
          msg := AckL1C1(adr,Put_AckL1C1,m,inmsg.src, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
          Send_fwd(msg, m);
          RemoveElement_cacheL1C1(cbe.cacheL1C1, inmsg.src);
          if (VectorCount_cacheL1C1(cbe.cacheL1C1) = 0) then
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_I;
            return true;
          endif;
          if !(VectorCount_cacheL1C1(cbe.cacheL1C1) = 0) then
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_S;
            return true;
          endif;
        
        case PutSL1C1:
          msg := AckL1C1(adr,Put_AckL1C1,m,inmsg.src, 0); -- SanyaSriv: just making all messages uncorrupted for now, can be changed later
          Send_fwd(msg, m);
          RemoveElement_cacheL1C1(cbe.cacheL1C1, inmsg.src);
          if !(VectorCount_cacheL1C1(cbe.cacheL1C1) = 0) then
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_S;
            return true;
          endif;
          if (VectorCount_cacheL1C1(cbe.cacheL1C1) = 0) then
            Clear_perm(adr, m);
            cbe.State := directoryL1C1_I;
            return true;
          endif;
        
        else return false;
      endswitch;
      
    endswitch;
    endalias;
    endalias;
    return false;
    end;

--Backend/Murphi/MurphiModular/GenResetFunc

  procedure System_Reset();
  begin
  Reset_perm();
  Reset_NET_();
  ResetMachine_();
  end;
  
-- TODO: everytime we take a tick, decrement the counter to represent that 1 cycle has passed
-- TODO: Add fucntion for decrementing, and decrement everytime a procedure is called below. 
--Backend/Murphi/MurphiModular/GenRules
  ----Backend/Murphi/MurphiModular/Rules/GenAccessRuleSet
    ruleset m:OBJSET_cacheL1C1 do
    ruleset adr:Address do
      alias cbe:i_cacheL1C1[m].cb[adr] do
    
      rule "cacheL1C1_I_store"
        cbe.State = cacheL1C1_I & network_ready() 
      ==>
        FSM_Access_cacheL1C1_I_store(adr, m);
        Tick();
      endrule;
    
      rule "cacheL1C1_I_load"
        cbe.State = cacheL1C1_I & network_ready() 
      ==>
        FSM_Access_cacheL1C1_I_load(adr, m);
        Tick();
      endrule;
    
      rule "cacheL1C1_M_store"
        cbe.State = cacheL1C1_M 
      ==>
        FSM_Access_cacheL1C1_M_store(adr, m);
        Tick();
      endrule;
    
      rule "cacheL1C1_M_load"
        cbe.State = cacheL1C1_M 
      ==>
        FSM_Access_cacheL1C1_M_load(adr, m);
        Tick();
      endrule;
    
      rule "cacheL1C1_M_evict"
        cbe.State = cacheL1C1_M & network_ready() 
      ==>
        FSM_Access_cacheL1C1_M_evict(adr, m);
        Tick();
      endrule;
    
      rule "cacheL1C1_S_store"
        cbe.State = cacheL1C1_S & network_ready() 
      ==>
        FSM_Access_cacheL1C1_S_store(adr, m);
        Tick();
      endrule;
    
      rule "cacheL1C1_S_load"
        cbe.State = cacheL1C1_S 
      ==>
        FSM_Access_cacheL1C1_S_load(adr, m);
        Tick();
      endrule;
    
      rule "cacheL1C1_S_evict"
        cbe.State = cacheL1C1_S & network_ready() 
      ==>
        FSM_Access_cacheL1C1_S_evict(adr, m);
        Tick();
      endrule;
      endalias;
    endruleset;
    endruleset;
    
  ----Backend/Murphi/MurphiModular/Rules/GenEventRuleSet
  ----Backend/Murphi/MurphiModular/Rules/GenNetworkRule
    ruleset dst:Machines do
        ruleset src: Machines do
          ruleset corruption:0..1 do
            alias msg:fwd[dst][0] do
              rule "Receive fwd"
                cnt_fwd[dst] > 0
              ==>
            if IsMember(dst, OBJSET_directoryL1C1) then
              if FSM_MSG_directoryL1C1(msg, dst, corruption) then
                  Pop_fwd(dst, src);
                  -- SanyaSriv: call the tick counter because we have taken a global step in here
                  Tick();
              endif;
            elsif IsMember(dst, OBJSET_cacheL1C1) then
              if FSM_MSG_cacheL1C1(msg, dst, corruption) then
                  Pop_fwd(dst, src);
                  -- SanyaSriv: call the tick counter because we have taken a global step in here
                  Tick();
              endif;
            else error "unknown machine";
            endif;
    
              endrule;
            endalias;
        endruleset;
      endruleset;
    endruleset;
    
    ruleset dst:Machines do
        ruleset src: Machines do
          ruleset corruption:0..1 do
            alias msg:resp[dst][0] do
              rule "Receive resp"
                cnt_resp[dst] > 0
              ==>
            if IsMember(dst, OBJSET_directoryL1C1) then
              if FSM_MSG_directoryL1C1(msg, dst, corruption) then
                  Pop_resp(dst, src);
                  -- SanyaSriv: call the tick counter because we have taken a global step in here
                  Tick();
              endif;
            elsif IsMember(dst, OBJSET_cacheL1C1) then
              if FSM_MSG_cacheL1C1(msg, dst, corruption) then
                  Pop_resp(dst, src);
                  -- SanyaSriv: call the tick counter because we have taken a global step in here
                  Tick();
              endif;
            else error "unknown machine";
            endif;
    
              endrule;
            endalias;
        endruleset;
      endruleset;
    endruleset;
    
    ruleset dst:Machines do
        ruleset src: Machines do
          ruleset corruption: 0..1 do
            alias msg:req[dst][0] do
              rule "Receive req"
                cnt_req[dst] > 0
              ==>
            if IsMember(dst, OBJSET_directoryL1C1) then
              if FSM_MSG_directoryL1C1(msg, dst, corruption) then
                  Pop_req(dst, src);
                  -- SanyaSriv: call the tick counter because we have taken a global step in here
                  Tick();
              endif;
            elsif IsMember(dst, OBJSET_cacheL1C1) then
              if FSM_MSG_cacheL1C1(msg, dst, corruption) then
                  Pop_req(dst, src);
                  -- SanyaSriv: call the tick counter because we have taken a global step in here
                  Tick();
              endif;
            else error "unknown machine";
            endif;
    
              endrule;
            endalias;
        endruleset;
      endruleset;
    endruleset;

    ruleset dst:Machines do
        ruleset src: Machines do
          ruleset corruption:0..1 do
            alias msg:ping[dst][0] do
              rule "Receive ping"
                cnt_ping[dst] > 0
              ==>
            if IsMember(dst, OBJSET_directoryL1C1) then
              if FSM_MSG_directoryL1C1(msg, dst, corruption) then
                  Pop_ping(dst, src);
                  -- SanyaSriv: call the tick counter because we have taken a global step in here
                  Tick();
              else
                Pop_ping(dst, src);
                  -- SanyaSriv: call the tick counter because we have taken a global step in here
                  Tick();
              endif;
            elsif IsMember(dst, OBJSET_cacheL1C1) then
                if FSM_MSG_cacheL1C1(msg, dst, corruption) then
                  Pop_ping(dst, src);
                  -- SanyaSriv: call the tick counter because we have taken a global step in here
                  Tick();
                else
                  Pop_ping(dst, src);
                  -- SanyaSriv: call the tick counter because we have taken a global step in here
                  Tick();
                endif;
            else error "unknown machine";
            endif;
    
              endrule;
            endalias;
        endruleset;
      endruleset;
    endruleset;
    

--Backend/Murphi/MurphiModular/GenStartStates

  startstate
    System_Reset();
  endstartstate;

--Backend/Murphi/MurphiModular/GenInvariant