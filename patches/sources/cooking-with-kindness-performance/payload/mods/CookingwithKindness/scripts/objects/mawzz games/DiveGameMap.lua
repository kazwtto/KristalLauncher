local DiveGameMap, super = Class(Object, "DiveGameMap")

function DiveGameMap:init(x,y,w,h)
    super.init(self,x,y,884,802)

    self.coral_bg = Sprite("objects/mawzz_games/divinggame/bg_coral")
    self:addChild(self.coral_bg)
    
    self:setOriginExact(0.5,0.5)
    self.sprite = Sprite("objects/mawzz_games/divinggame/bg_2")
    self:addChild(self.sprite)

    self.floor_sprite = Sprite("objects/mawzz_games/divinggame/floor_tobedestroyed",21,782)
    self:addChild(self.floor_sprite)
    self.colliders = {}

    self.fish = {} --Table of all the current fish in the map
    self.bombs = {} --Table of all the bombs in the map. We loop through this in the wave code

    self.node_pos = {}
    --Spawn a fish every 0.7 seconds
    Game.battle.timer:every(0.7, function()
        local random_xspeed = love.math.random(2,5) --Randomizes the fish's speed
        local random_y = love.math.random(70,774) --Randomizes the fish's y coordinate

        local fish = Sprite("objects/mawzz_games/divinggame/fish",869,random_y)
        fish:setScale(2)
        fish:setLayer(self.sprite.layer - 10)

        fish.physics.speed_x = -random_xspeed
        table.insert(self.fish,fish)
        self:addChild(fish)
    end)

    -- The map's polygons
   self.polygons = {
        {{ 507, 354 },{ 513, 346 },{ 520, 339 },{ 539, 331 },{ 582, 323 },
        { 616, 309 },{ 636, 290 },{ 664, 279 },{ 674, 273 },{ 713, 269 },
        { 742, 281 },{ 753, 292 },{ 765, 308 },{ 784, 325 },{ 787, 327 },
        { 746, 445 },{ 727, 439 },{ 701, 429 },{ 682, 417 },{ 654, 415 },
        { 622, 425 },{ 597, 435 },{ 557, 437 },{ 531, 433 },{ 527, 425 },
        { 517, 403 },{ 517, 391 },{ 509, 370 },{ 507, 354 }},
        
        {{ 787, 327 },{ 813, 337 },{ 825, 335 },{ 851, 327 },{ 865, 313 },
        { 869, 295 },{ 869, 279 },{ 869, 252 },{ 849, 219 },{ 834, 201 },
        { 816, 191 },{ 770, 187 },{ 748, 175 },{ 730, 161 },{ 711, 145 },
        { 699, 126 },{ 851, 134 },{ 877, 202 },{ 882, 277 },{ 877, 352 },
        { 843, 392 }},
        
        {{ 746, 445 },{ 765, 465 },{ 782, 473 },{ 791, 486 },{ 791, 525 },
        { 789, 532 },{ 789, 569 },{ 793, 576 },{ 793, 620 },{ 773, 672 },
        { 765, 694 },{ 860, 667 },{ 852, 479 },{ 793, 414 }},
        
        {{ 765, 694 },{ 763, 701 },{ 757, 709 },{ 749, 715 },{ 741, 715 },
        { 738, 717 },{ 645, 717 },{ 638, 715 },{ 624, 715 },{ 609, 713 },
        { 606, 711 },{ 600, 711 },{ 596, 709 },{ 589, 709 },{ 584, 705 },
        { 579, 703 },{ 576, 701 },{ 565, 701 },{ 561, 699 },{ 521, 699 },
        { 518, 697 },{ 515, 697 },{ 512, 695 },{ 508, 693 },{ 504, 691 },
        { 491, 691 },{ 485, 697 },{ 483, 697 },{ 473, 707 },{ 471, 707 },
        { 462, 713 },{ 451, 723 },{ 448, 729 },{ 443, 737 },{ 439, 744 },
        { 439, 749 },{ 427, 763 },{ 425, 763 },{ 421, 769 },{ 417, 781 },
        { 771, 774 },{ 765, 694 }},
        
        {{ 417, 781 },{ 417, 802 },{ 0, 802 },{ 0, 781 },{ 417, 781 }},
        
        {{ 545, 575 },{ 532, 575 },{ 527, 573 },{ 505, 573 },{ 498, 577 },
        { 491, 577 },{ 485, 573 },{ 469, 573 },{ 463, 577 },{ 456, 577 },
        { 441, 575 },{ 430, 571 },{ 411, 571 },{ 394, 559 },{ 385, 557 },
        { 367, 557 },{ 335, 549 },{ 325, 547 },{ 315, 540 },{ 309, 531 },
        { 284, 603 },{ 334, 617 },{ 370, 625 },{ 382, 631 },{ 392, 637 },
        { 406, 629 },{ 420, 629 },{ 455, 629 },{ 472, 621 },{ 504, 621 },
        { 519, 627 },{ 523, 619 },{ 531, 611 },{ 531, 609 },{ 539, 601 },
        { 539, 589 },{ 549, 579 },{ 545, 575 }},
        
        {{  545,  575 },{  532,  575 },{  527,  573 },{  505,  573 },{  498,  577 },
        {  491,  577 },{  485,  573 },{  469,  573 },{  463,  577 },{  456,  577 },
        {  441,  575 },{  430,  571 },{  411,  571 },{  394,  559 },{  385,  557 },
        {  367,  557 },{  335,  549 },{  325,  547 },{  315,  540 },{  309,  531 },
        {  284,  603 },{  334,  617 },{  370,  625 },{  382,  631 },{  392,  637 },
        {  406,  629 },{  420,  629 },{  455,  629 },{  472,  621 },{  504,  621 },
        {  519,  627 },{  523,  619 },{  531,  611 },{  531,  609 },{  539,  601 },
        {  539,  589 },{  549,  579 },{  545,  575 }},
        
        {{  0,  781 },{  2,  781 },{  2,  678 },{  0,  678 }},
        
        {{  2,  678 },{  9,  665 },{  33,  641 },{  35,  641 },{  60,  627 },
        {  77,  621 },{  93,  617 },{  105,  617 },{  109,  615 },{  127,  615 },
        {  133,  613 },{  147,  613 },{  151,  611 },{  159,  611 },{  163,  609 },
        {  187,  609 },{  192,  607 },{  225,  607 },{  229,  609 },{  252,  609 },
        {  259,  607 },{  274,  601 },{  279,  601 },{  284,  603 },{  309,  531 },
        {  307,  525 },{  293,  509 },{  277,  501 },{  268,  497 },{  261,  497 },
        {  257,  495 },{  251,  495 },{  248,  493 },{  241,  493 },{  238,  491 },
        {  229,  491 },{  226,  489 },{  219,  489 },{  216,  487 },{  209,  487 },
        {  206,  485 },{  187,  485 },{  184,  483 },{  181,  483 },{  177,  481 },
        {  168,  473 },{  161,  469 },{  152,  463 },{  147,  463 },{  131,  457 },
        {  113,  447 },{  95,  431 }},
        
        {{  95,  431 },{  95,  427 },{  100,  423 },{  114,  415 },{  125,  407 },
        {  127,  406 },{  127,  397 },{  143,  381 },{  193,  363 },{  225,  349 },
        {  235,  339 },{  235,  333 },{  237,  331 },{  237,  323 },{  246,  315 },
        {  265,  305 },{  269,  301 },{  269,  287 },{  273,  287 },{  310,  275 },
        {  325,  263 },{  327,  261 },{  327,  255 },{  329,  253 },{  329,  247 },
        {  331,  245 },{  331,  231 },{  79,  233 }},
        
        {{  331,  231 },{  350,  219 },{  359,  219 },{  367,  217 },{  393,  197 },
        {  405,  183 },{  438,  167 },{  463,  161 },{  471,  161 },{  474,  159 },
        {  489,  159 },{  495,  154 },{  495,  143 },{  503,  127 },{  503,  115 },
        {  501,  113 },{  501,  105 },{  487,  93 },{  483,  83 },{  461,  61 },
        {  455,  57 },{  449,  45 },{  449,  40 },{  323,  211 }},
        
        {{  699,  126 },{  679,  103 },{  675,  103 },{  663,  93 },{  661,  89 },
        {  661,  65 },{  659,  62 },{  659,  57 },{  645,  43 },{  726,  90 },{  699,  126 }}}

    self.edges = {}
    for i = 1, #self.polygons do
        table.insert(self.edges, Utils.getPolygonEdges(self.polygons[i]))
    end

    --Snosib - needed polygons, not colliders, for pathfinding. Same info, just slightly different way of keeping it.
        
    --The map's collision
    self.map_collision = self:addChild(Solid(false,0,0))
    self.map_collision.collider = ColliderGroup(self, {
        PolygonCollider(self.map_collision, self.polygons[1]),

        PolygonCollider(self.map_collision, self.polygons[2]),

        PolygonCollider(self.map_collision, self.polygons[3]),

        PolygonCollider(self.map_collision, self.polygons[4]),

        PolygonCollider(self.map_collision, self.polygons[5]),

        PolygonCollider(self.map_collision, self.polygons[6]),

        PolygonCollider(self.map_collision, self.polygons[7]),

        PolygonCollider(self.map_collision, self.polygons[8]),

        PolygonCollider(self.map_collision, self.polygons[9]),

        PolygonCollider(self.map_collision, self.polygons[10]),

        PolygonCollider(self.map_collision, self.polygons[11]),

        PolygonCollider(self.map_collision, self.polygons[12]),

        Hitbox(self.map_collision, 640,-55,10,100),

        Hitbox(self.map_collision,446,-55,10,110)
    })

    --If you have the treasure and collide with this, you win
    self.win_collider = Hitbox(self,450,37,215,2)

    --Table of the bombs+their info. X, Y, direction, inverted
    self.bomb_locations = {
        {490,249,"vertical",false},
        {392,444,"horizontal",false},
    }

    --The treasure at the bottom
    self.treasure = (Treasure(166,754))
    self:addChild(self.treasure)

    --Spawn the bombs
    for i,v in ipairs(self.bomb_locations) do
        local bomb = Bomb(v[1],v[2])
        bomb.dir = v[3]
        bomb.inverse_dir = v[4]
        self:addChild(bomb)
        table.insert(self.bombs,bomb)
    end
end

function DiveGameMap:update()
    super.update(self)

    -- Remove off-screen fish and their references together. The old list kept
    -- every removed fish forever, making this loop grow for the whole dive.
    local fish_write = 1
    for fish_read = 1, #self.fish do
        local fish = self.fish[fish_read]
        if not fish.parent or fish.x < 0 then
            if fish.parent then
                fish:remove()
            end
        else
            self.fish[fish_write] = fish
            fish_write = fish_write + 1
        end
    end
    for i = #self.fish, fish_write, -1 do
        self.fish[i] = nil
    end
end

function DiveGameMap:draw()
    super.draw(self)

    --[[for _, point in ipairs(self.node_pos) do
        local x = point[1]
        local y = point[2]
        love.graphics.circle("fill", x, y, 4)
    end

    self.win_collider:drawFor(self,1,0,0,1)]]
end

return DiveGameMap