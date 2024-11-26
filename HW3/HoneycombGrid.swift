import SwiftUI
import AVFoundation

class StackManager: ObservableObject {
    @Published var placedStacks: [StackData] = []   // 管理已放置的堆叠
    @Published var backgroundStacks: [StackData] = []  // 管理背景堆叠
    @Published var allStacks: [StackData] = []
    @Published var availablePositions: [CGPoint] = [] // 动态维护可用位置
    let squareSize: CGFloat = 70 // 應該是 CGFloat
    let spacing: CGFloat = 10   // 應該是 CGFloat

    func initializeBackgroundStacks(squarePositions: [CGPoint]) {
        var usedColors: [Color] = [] // 用于记录已使用的颜色
        var uniqueColors: [Color] = []
        
        // 确保生成五个唯一颜色
        while uniqueColors.count < 5 {
            let newColor = Color.random()
            if !usedColors.contains(newColor) { // 检查是否重复
                uniqueColors.append(newColor)
                usedColors.append(newColor) // 将新颜色记录到已使用的颜色列表
            }
        }
        
        // 随机选取五个不同的位置
        let positions = squarePositions.shuffled().prefix(5)
        
        // 使用颜色和位置生成堆叠
        backgroundStacks = zip(positions, uniqueColors).map { position, color in
            StackData(
                id: UUID(),
                position: position,
                cylinderHeight: Int.random(in: 2...4),
                color: color,
                isMovable: false,
                removee:0
            )
        }
        updateAvailablePositions(squarePositions: squarePositions)
    }


    func addStack(position: CGPoint, color: Color, squarePositions: [CGPoint]) {
        let newStack = StackData(
            id: UUID(),
            position: position,
            cylinderHeight: Int.random(in: 2...4),
            color: color,
            isMovable: true,
            removee:0
        )
        placedStacks.append(newStack)
        // 從 availablePositions 移除該位置
            if let index = availablePositions.firstIndex(of: position) {
                availablePositions.remove(at: index)
            }
    }
    func moveBackgroundStacksToPlaced() {
        // 合并 backgroundStacks 和 placedStacks
        allStacks = placedStacks + backgroundStacks
        // 如果需要同时更新 availablePositions，确保合并后正确维护
        updateAvailablePositions(squarePositions: availablePositions)
    }
    func resetStacks(squarePositions: [CGPoint]) {
        placedStacks = (0..<3).map { index in
            StackData(
                id: UUID(),
                position: CGPoint(x: 70 + index * 120, y: 670),
                cylinderHeight: Int.random(in: 2...4),
                color: Color.random(),
                isMovable: true,
                removee:0
            )
        }
        updateAvailablePositions(squarePositions: squarePositions)
    }

    func updateAvailablePositions(squarePositions: [CGPoint]) {
        // 获取当前所有占用的位置
        let occupiedPositions = (placedStacks + backgroundStacks).map { $0.position }

        // 动态更新可用位置
        availablePositions = squarePositions.filter { !occupiedPositions.contains($0) }
    }
    func findAdjacentStacks(position: CGPoint, color: Color, cylinderHeight: Int) -> [StackData] {
        // 查找相鄰位置的偏移量
        let offsets = [
            CGPoint(x: 0, y: -squareSize - spacing), // 上
            CGPoint(x: 0, y: squareSize + spacing), // 下
            CGPoint(x: -squareSize - spacing, y: 0), // 左
            CGPoint(x: squareSize + spacing, y: 0)  // 右
        ]

        // 計算相鄰位置
        let adjacentPositions = offsets.map { offset in
            CGPoint(x: position.x + offset.x, y: position.y + offset.y)
        }
        print("相鄰座標\(adjacentPositions)")
        // 過濾相鄰的堆疊，但排除自己
        return allStacks.filter { stack in
            adjacentPositions.contains(where: { $0.isCloseTo(stack.position) }) &&
            stack.color == color &&
            !stack.position.isCloseTo(position) // 排除自己
        }
    }

    func updateCylinderHeight(for stack: StackData, with adjacentStacks: [StackData]) {
        if let index = placedStacks.firstIndex(where: { $0.id == stack.id }) {
            placedStacks[index].cylinderHeight += adjacentStacks.count
            objectWillChange.send()
        }
    }
}


struct StackData {
    let id: UUID
    var position: CGPoint
    var cylinderHeight: Int
    let color: Color
    var isMovable: Bool // 新增屬性
    var removee : Int
}

struct Score {
    static let targetScores: [Int] = [75,100,125,150,175,200]//75,100,125,150,175,200
}

struct HoneycombGrid: View {
    @StateObject private var stackManager = StackManager()  // 使用 StateObject 來保持 StackManager 狀態
    @Binding var isGameStarted: Bool
    @Environment(\.dismiss) var dismiss
    
    let size: Size
    let squareSize: CGFloat = 70
    let spacing: CGFloat = 10

    @State private var allMoved = false
    @State private var shouldAddNewStacks = false
    @State private var initialStacks: [StackData] = []  // 儲存初始化的堆疊
    @State private var score: Int = 0 // 用來儲存玩家的分數
    @State private var currentTargetScore: Int = 0
    @State private var showCongratsPage: Bool = false
    @State private var showGameOverSheet: Bool = false
    @State private var soundEffect: AVAudioPlayer?
    @State private var elapsedTime: Int = 0 // 用于记录秒数
    @State private var isGameActive: Bool = false // 控制计时器状态
    @State private var timer: Timer? // 定义计时器

    var body: some View {
        ZStack {
            // 背景
            Text("pionts：\(score)/\(currentTargetScore)")
                .font(.custom("Ludicrous", size: 40))
                .bold()
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .padding(.bottom, 700)
                //.padding(.leading, 10)
            SquareBackground(
                rows: Int(size.rows),
                columns: Int(size.columns),
                squareSize: squareSize,
                spacing: spacing,
                color: Color.brown.opacity(0.3),
                size: size
            )
            .padding(.bottom, 100)
            
            // 顯示初始化的堆疊（這些堆疊不可移動）
            ForEach(stackManager.backgroundStacks, id: \.id) { stack in
                SquareCylinder(
                    squareSize: squareSize,
                    cylinderHeight: stack.cylinderHeight,
                    color: stack.color,
                    xPosition: stack.position.x,
                    yPosition: stack.position.y,
                    squarePositions: [],
                    size: size,
                    isMovable: false // 設定背景堆疊為不可移動
                )
            }
            
            // 顯示已放置的堆疊（這些堆疊在移動後才會顯示）
            ForEach(stackManager.placedStacks, id: \.id) { stack in
                SquareCylinder(
                    squareSize: squareSize,
                    cylinderHeight: stack.cylinderHeight,
                    color: stack.color,
                    xPosition: stack.position.x,
                    yPosition: stack.position.y,
                    squarePositions: SquareBackground.calculateSquarePositions(
                        rows: Int(size.rows),
                        columns: Int(size.columns),
                        squareSize: squareSize,
                        spacing: spacing,
                        size: size
                    ),
                    size: size,
                    isMovable: true// 顯示這些堆疊是可移動的
                )
                .onTapGesture {
                    checkAllMoved() // 檢查所有堆疊是否都已移動
                    if stack.removee >= 10{
                        playSoundEffect(named: "diving1")
                        withAnimation(.easeOut(duration: 1.2)) {
                            // 播放移除動畫
                            stackManager.placedStacks.removeAll { $0.id == stack.id }
                        }
                        score += stack.removee
                        if score >= currentTargetScore {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                stopTimer()
                                showCongratsPage = true
                                playSoundEffect(named: "win") // 播放音效
                            }
                        }
                        // 將位置加入可用位置
                        if !stackManager.availablePositions.contains(where: { $0.isCloseTo(stack.position) }) {
                            stackManager.availablePositions.append(stack.position)
                        }
                    }
                    if stackManager.availablePositions.isEmpty {
                        showGameOverSheet = true // 顯示遊戲結束頁面
                        playSoundEffect(named: "lose") // 播放音效
                    }
                }
            }
            // 根據 shouldAddNewStacks 來控制新增堆疊的顯示
                if shouldAddNewStacks {
                ResetStack(
                    squareSize: squareSize,
                    squarePositions: SquareBackground.calculateSquarePositions(
                        rows: Int(size.rows),
                        columns: Int(size.columns),
                        squareSize: squareSize,
                        spacing: spacing,
                        size: size
                    ),
                    size: size,
                    onMoved: checkAllMoved // 呼叫 checkAllMoved() 檢查堆疊是否移動
                )
                
            }
        }
        .environmentObject(stackManager)
        .padding()
        .onAppear {
            if isGameStarted {
                //playSoundEffect(named: "backmusic")
                currentTargetScore = Score.targetScores.randomElement() ?? 250
                startTimer()
                // 初始化背景堆疊
                stackManager.initializeBackgroundStacks(
                    squarePositions: SquareBackground.calculateSquarePositions(
                        rows: Int(size.rows),
                        columns: Int(size.columns),
                        squareSize: squareSize,
                        spacing: spacing,
                        size: size
                    )
                    //count: 5
                )
                
                // 初始化互動堆疊
                stackManager.resetStacks(
                    squarePositions: SquareBackground.calculateSquarePositions(
                        rows: Int(size.rows),
                        columns: Int(size.columns),
                        squareSize: squareSize,
                        spacing: spacing,
                        size: size
                    )
                )
                stackManager.updateAvailablePositions(squarePositions: SquareBackground.calculateSquarePositions(
                    rows: Int(size.rows),
                    columns: Int(size.columns),
                    squareSize: squareSize,
                    spacing: spacing,
                    size: size
                ))
                stackManager.moveBackgroundStacksToPlaced()
            }
        }
        .sheet(isPresented: $showCongratsPage) {
            CongratsView(
                onReturnToLobby: {
                    showCongratsPage = false
                    isGameStarted = false
                    dismiss() // 返回大廳
                },
                onPlayAgain: {
                    showCongratsPage = false
                    score = 0
                    currentTargetScore = Score.targetScores.randomElement() ?? 250
                    stackManager.resetStacks(
                        squarePositions: SquareBackground.calculateSquarePositions(
                            rows: Int(size.rows),
                            columns: Int(size.columns),
                            squareSize: squareSize,
                            spacing: spacing,
                            size: size
                        )
                    )
                    stackManager.initializeBackgroundStacks(
                        squarePositions: SquareBackground.calculateSquarePositions(
                            rows: Int(size.rows),
                            columns: Int(size.columns),
                            squareSize: squareSize,
                            spacing: spacing,
                            size: size
                        )
                    )
                    isGameStarted = true
                    //resetGame() // 再玩一局
                },
                elapsedTime: elapsedTime
            )
        }
        .sheet(isPresented: $showGameOverSheet) {
            GameOverSheet(
                onReturnToLobby: {
                    showGameOverSheet = false
                    isGameStarted = false
                    dismiss()
                },
                onPlayAgain: {
                    showGameOverSheet = false
                    score = 0
                    currentTargetScore = Score.targetScores.randomElement() ?? 250
                    stackManager.resetStacks(
                        squarePositions: SquareBackground.calculateSquarePositions(
                            rows: Int(size.rows),
                            columns: Int(size.columns),
                            squareSize: squareSize,
                            spacing: spacing,
                            size: size
                        )
                    )
                    stackManager.initializeBackgroundStacks(
                        squarePositions: SquareBackground.calculateSquarePositions(
                            rows: Int(size.rows),
                            columns: Int(size.columns),
                            squareSize: squareSize,
                            spacing: spacing,
                            size: size
                        )
                    )
                    isGameStarted = true
                }
            )
        }


    }
    

    
    func checkAllMoved() {
        // 檢查所有堆疊是否已經移動
        if stackManager.placedStacks.allSatisfy({ !$0.isMovable }) {
            allMoved = true
            print("所有堆疊都移動過了！")
            
            DispatchQueue.main.async {
                // 新增三個堆疊
                stackManager.placedStacks.append(contentsOf: [
                    StackData(id: UUID(), position: CGPoint(x: 70, y: 670), cylinderHeight: Int.random(in: 2...4), color: Color.random(),isMovable: true,removee:0),
                    StackData(id: UUID(), position: CGPoint(x: 190, y: 670), cylinderHeight: Int.random(in: 2...4), color: Color.random(),isMovable: true,removee:0),
                    StackData(id: UUID(), position: CGPoint(x: 310, y: 670), cylinderHeight: Int.random(in: 2...4), color: Color.random(),isMovable: true,removee:0)
                ])  // 新堆疊加入到已放置堆疊列表中
                shouldAddNewStacks = false // 完成後禁用新的堆疊顯示
                resetStack() // 重設移動狀態
            }
        }
    }

    func resetStack() {
        // 重設移動標誌
        allMoved = false
    }
    func startTimer() {
        elapsedTime = 0 // 重置时间
        isGameActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    func stopTimer() {
        isGameActive = false
        timer?.invalidate() // 停止计时器
        timer = nil
    }
    func playSoundEffect(named soundName: String) {
        if let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") {
            //var soundEffect: AVAudioPlayer?
            do {
                soundEffect = try AVAudioPlayer(contentsOf: url)
                print("Attempting to play sound")
                soundEffect?.play()
            } catch {
                print("Error playing sound effect: \(error.localizedDescription)")
            }
        } else {
            print("Sound file not found: \(soundName)")
        }
    }
    func stopSoundEffect() {
        if let soundEffect = soundEffect {
            soundEffect.stop()
            soundEffect.currentTime = 0 // 重置播放位置
            print("Sound effect stopped.")
        } else {
            print("No sound effect to stop.")
        }
    }
}

struct CongratsView: View {
    var onReturnToLobby: () -> Void
    var onPlayAgain: () -> Void
    var elapsedTime:Int

    var body: some View {
        ZStack{
            Color(hue: 0.083, saturation: 0.266, brightness: 0.746).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Congratulations🎉")
                    .font(.custom("Ludicrous", size: 40))
                    .bold()
                    .padding()

                Text("你已達到目標分數😍😍")
                    .font(.title2)
                
                Text("您所花的時間：\(elapsedTime) 秒")
                    .font(.title2)

                Button(action: {
                    onPlayAgain()
                }) {
                    Label("再玩一局", systemImage: "arrow.counterclockwise.circle.fill")
                        .font(.title)
                        .padding()
                        .frame(maxWidth:200)
                        .background(Color(hue: 0.102, saturation: 0.478, brightness: 0.892))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    onReturnToLobby()
                }) {
                    Label("返回大廳", systemImage: "house.circle.fill")
                        .font(.title)
                        .padding()
                        .frame(maxWidth: 200)
                        .background(Color(hue: 0.103, saturation: 0.478, brightness: 0.892))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(15)
            .shadow(radius: 10)
            .padding()
        }
        
        
    }

}

struct GameOverSheet: View {
    var onReturnToLobby: () -> Void
    var onPlayAgain: () -> Void

    var body: some View {
        ZStack{
            Color(hue: 0.083, saturation: 0.266, brightness: 0.746).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Game over💥")
                    .font(.custom("Ludicrous", size: 40))
                    .bold()
                    //.padding()
                
                Text("格子已經放滿了😭😭")
                    .font(.title2)
                
                Button(action: {
                    onPlayAgain()
                }) {
                    Label("再玩一局", systemImage: "arrow.counterclockwise.circle.fill")
                        .font(.title)
                        .padding()
                        .frame(maxWidth:200)
                        .background(Color(hue: 0.103, saturation: 0.478, brightness: 0.892))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    onReturnToLobby()
                }) {
                    Label("返回大廳", systemImage: "house.circle.fill")
                        .font(.title)
                        .padding()
                        .frame(maxWidth: 200)
                        .background(Color(hue: 0.103, saturation: 0.478, brightness: 0.892))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(15)
            .shadow(radius: 10)
            .padding()
        }
    }

}
struct ResetStack: View {
    let squareSize: CGFloat
    let squarePositions: [CGPoint]
    let size: Size
    let onMoved: () -> Void

    var body: some View {
        ZStack {
            // 使用 ForEach 動態顯示三個堆疊
            ForEach(0..<3, id: \.self) { index in
                SquareCylinder(
                    squareSize: squareSize,
                    cylinderHeight: Int.random(in: 2...4),
                    color: Color.random(),
                    xPosition: CGFloat(70 + index * 120), // 設定堆疊顯示的位置
                    yPosition: 670,
                    squarePositions: squarePositions,
                    size: size,
                    isMovable: true // 設定為可以移動
                )
                .onTapGesture {
                    onMoved() // 呼叫 onMoved，創建新的堆疊
                }
            }
        }
    }
}

struct SquareCylinder: View {
    
    let squareSize: CGFloat
    var cylinderHeight: Int
    let color: Color
    @State private var dragOffset = CGSize.zero
    @State private var currentPosition = CGPoint.zero
    @State private var hasMoved = false

    let xPosition: CGFloat
    let yPosition: CGFloat
    let squarePositions: [CGPoint]
    let size: Size
    @State var isMovable: Bool
    @State private var soundEffect: AVAudioPlayer?
    
    @EnvironmentObject var stackManager: StackManager
    
    var body: some View {
        
        ZStack {
            ForEach(0..<cylinderHeight, id: \.self) { layer in
                SquareShape()
                    .fill(color)
                    .frame(width: squareSize, height: squareSize)
                    .offset(x: dragOffset.width, y: dragOffset.height - CGFloat(layer) * 7)
                    .position(x: currentPosition.x, y: currentPosition.y)
                    .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if isMovable && !hasMoved {
                                    dragOffset = value.translation
                                }
                                //playSoundEffect(named: "put") // 播放音效
                            }
                            .onEnded { _ in
                                if isMovable && !hasMoved {
                                    handleRelease()
                                }
                                stackManager.moveBackgroundStacksToPlaced()
                            }
                    )
            }
        }
        .onAppear {
            if yPosition == 670 {
                // 使用動畫進場
                currentPosition = CGPoint(x: UIScreen.main.bounds.width + squareSize, y: yPosition) // 屏幕右側
                withAnimation(.linear(duration: 0.8)) {
                    currentPosition = CGPoint(x: xPosition, y: yPosition) // 移動到最終位置
                }
            } else {
                currentPosition = CGPoint(x: xPosition, y: yPosition)
            }
            stackManager.moveBackgroundStacksToPlaced()
        }
    }
    
    private func handleRelease() {
        let releasePoint = CGPoint(
            x: currentPosition.x + dragOffset.width,
            y: currentPosition.y + dragOffset.height
        )
        
        hasMoved = true

        if let nearestPosition = findNearestPosition(from: releasePoint) {
            playSoundEffect(named: "put") // 播放音效
            // 更新堆疊移動後的位置
            if let index = stackManager.placedStacks.firstIndex(where: { $0.position.isCloseTo(currentPosition) }) {
                stackManager.placedStacks[index].position = nearestPosition
                stackManager.placedStacks[index].isMovable = false
            }
            currentPosition = nearestPosition

            // 找到相鄰堆疊並處理合併
            let adjacentStacks = stackManager.findAdjacentStacks(
                position: nearestPosition,
                color: color,
                cylinderHeight: cylinderHeight
            )
            mergeAdjacentStacks(at: nearestPosition, with: adjacentStacks)

            // 如果堆疊高度超過 10，執行移除並加入動畫
            if let index = stackManager.placedStacks.firstIndex(where: { $0.position.isCloseTo(currentPosition) }) {
                if stackManager.placedStacks[index].cylinderHeight >= 10 {
                    /*if !stackManager.availablePositions.contains(where: { $0.isCloseTo(currentPosition) }) {
                        stackManager.availablePositions.append(currentPosition)
                    }*/
                    stackManager.placedStacks[index].removee = stackManager.placedStacks[index].cylinderHeight
                    //stackManager.placedStacks.remove(at: index)

                    // 顯示向上飄的動畫
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // 在需要時更新相關 UI 或狀態
                    }
                }
            }

            // 移除當前位置的空閒狀態
            if let index = stackManager.availablePositions.firstIndex(of: nearestPosition) {
                stackManager.availablePositions.remove(at: index)
            }
            
        } else {
            print("No available position found for release point.")
            playSoundEffect(named: "oh")
            hasMoved = false
        }

        dragOffset = .zero
    }


    private func mergeAdjacentStacks(at position: CGPoint, with adjacentStacks: [StackData]) {
        // 找到所有與當前顏色相同的相鄰堆疊
        let sameColorStacks = adjacentStacks.filter { $0.color == color }
        
        if !sameColorStacks.isEmpty {
            var totalHeight = cylinderHeight
            var positionsToRemove: [UUID] = []
            var positionsToRelease: [CGPoint] = [] // 儲存需要釋放的位置
            // 累加高度並記錄要移除的堆疊 ID 和位置
            for stack in sameColorStacks {
                totalHeight += stack.cylinderHeight
                positionsToRemove.append(stack.id)
                positionsToRelease.append(stack.position)
            }
            print("加\(totalHeight)")
            
            // 更新當前堆疊的高度
            if let index = stackManager.placedStacks.firstIndex(where: { $0.position.isCloseTo(position) }) {
                stackManager.placedStacks[index].cylinderHeight = totalHeight
            }

            // 在移除堆疊前，將其位置釋放到 availablePositions
            for releasePosition in positionsToRelease {
                if !stackManager.availablePositions.contains(where: { $0.isCloseTo(releasePosition) }) {
                    stackManager.availablePositions.append(releasePosition)
                }
            }

            // 從堆疊列表中移除相鄰堆疊
            for id in positionsToRemove {
                if let index = stackManager.placedStacks.firstIndex(where: { $0.id == id }) {
                    stackManager.placedStacks.remove(at: index)
                }else if let index = stackManager.backgroundStacks.firstIndex(where: { $0.id == id }) {
                    stackManager.backgroundStacks.remove(at: index)
                }
            }

            // 通知畫面更新
            DispatchQueue.main.async {
                self.stackManager.objectWillChange.send()
            }
        }
    }

    private func findNearestPosition(from point: CGPoint) -> CGPoint? {
        return stackManager.availablePositions
            .filter { distance(from: point, to: $0) < squareSize }
            .min(by: { distance(from: point, to: $0) < distance(from: point, to: $1) })
    }

    private func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        return sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2))
    }
    
    func playSoundEffect(named soundName: String) {
        if let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") {
            //var soundEffect: AVAudioPlayer?
            do {
                soundEffect = try AVAudioPlayer(contentsOf: url)
                print("Attempting to play sound")
                soundEffect?.play()
            } catch {
                print("Error playing sound effect: \(error.localizedDescription)")
            }
        } else {
            print("Sound file not found: \(soundName)")
        }
    }
}

extension CGPoint {
    func isCloseTo(_ other: CGPoint, tolerance: CGFloat = 1.0) -> Bool {
        return abs(self.x - other.x) < tolerance && abs(self.y - other.y) < tolerance
    }
}


extension Color {
    static let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .gray, .purple,.white,.pink]
    
    static func random() -> Color {
        return colors.randomElement() ?? .gray
    }
}


struct SquareBackground: View {
    let rows: Int
    let columns: Int
    let squareSize: CGFloat
    let spacing: CGFloat
    let color: Color
    let size: Size
    
    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { column in
                        SquareShape()
                            .fill(color)
                            .frame(width: squareSize, height: squareSize)
                    }
                }
            }
        }
    }
    
    static func calculateSquarePosition(row: Int, column: Int, squareSize: CGFloat, spacing: CGFloat, size: Size) -> CGPoint {
        let x = CGFloat(column) * (squareSize + spacing) + size.x_position
        let y = CGFloat(row) * (squareSize + spacing) + size.y_position
        return CGPoint(x: x, y: y)
    }
    
    static func calculateSquarePositions(rows: Int, columns: Int, squareSize: CGFloat, spacing: CGFloat, size: Size) -> [CGPoint] {
        var positions: [CGPoint] = []
        
        for row in 0..<rows {
            for column in 0..<columns {
                let position = calculateSquarePosition(
                    row: row,
                    column: column,
                    squareSize: squareSize,
                    spacing: spacing,
                    size: size
                )
                positions.append(position)
            }
        }
        
        return positions
    }
}

struct SquareShape: Shape {
    var cornerRadius: CGFloat = 10
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        }
    }
}

