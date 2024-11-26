//
//  ContentView.swift
//  HW3
// //  Created by user12 on 2024/11/13.
//
import SwiftUI
import Observation
import AVFoundation

struct Size: Identifiable {
    let id = UUID()          // 唯一識別符號
    let rows: CGFloat
    let columns: CGFloat            
    let x_position: CGFloat
    let y_position: CGFloat

}
struct StackItem {
    //let id: UUID
    let xPosition: CGFloat
    let yPosition: CGFloat
    var isMoved: Bool = false // 默認為未移動
}
struct SampleData {
    static let Data = [
        Size(rows:5 ,columns:5,x_position:35 ,y_position:187),
        Size(rows:5 ,columns:3,x_position:105,y_position:187),
        Size(rows:4 ,columns:4,x_position:65 ,y_position:227)
    ]
    static let Color=["red","orange","yellow","green","blue","gray","purple"]
}

struct ContentView: View {
    @State private var isGameStarted = false
    @State private var soundEffect: AVAudioPlayer?
    @State private var isSheetPresented = false
    //@State  var stackManager = StackManager()
    
    var body: some View {
        //let randomSize = SampleData.Data.randomElement() ?? SampleData.Data[0] // 隨機選擇一筆資料
        
        ZStack {
            // 背景色
            Image("background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                // 遊戲標題
                Text("Stack Sort")
                    .font(.custom("Ludicrous", size: 50))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hue: 1.0, saturation: 0.506, brightness: 0.492))
                    .padding(.top, 50)

                Spacer()
                // 遊戲開始按鈕
                Button(action: {
                    isSheetPresented = true // Show the sheet
                }) {
                    Text("introduce")
                        .font(.custom("Ludicrous", size: 30))
                        .foregroundColor(Color(hue: 0.098, saturation: 0.955, brightness: 0.449, opacity: 1.0))
                }
                .padding(.bottom, 15)
                .sheet(isPresented: $isSheetPresented) {
                    // Content of the sheet
                    IntroduceView()
                }
                // 遊戲開始按鈕
                Button(action: {
                    isGameStarted.toggle()
                    playSoundEffect(named: "backmusic")
                }) {
                    Text("game start")
                        .font(.custom("Ludicrous", size: 40))
                        //.fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color(hue: 0.105, saturation: 0.731, brightness: 0.89))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .padding(.bottom, 50)
                .fullScreenCover(isPresented: $isGameStarted) {
                    HoneycombGrid(isGameStarted: $isGameStarted, 
                                  size: SampleData.Data.randomElement() ?? SampleData.Data[0]
                    ).environmentObject(StackManager())// 傳遞隨機選擇的 size
                }
                //Spacer()
            }
        }
    }
    func playSoundEffect(named soundName: String) {
        if let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") {
            do {
                soundEffect = try AVAudioPlayer(contentsOf: url)
                soundEffect?.numberOfLoops = -1 // 設置無限循環
                //soundEffect?.volume = 0.5       // 可調整音
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
struct IntroduceView: View {
    var body: some View {
        ScrollView { // Use ScrollView in case the content is long
            VStack(alignment: .leading, spacing: 20) {
                Text("遊戲簡介")
                    .font(.title)
                    .bold()
                    .padding(.bottom, 10)

                Text("一款打發時間的益智小遊戲🎮")
                    .font(.body)
                    .padding(.bottom)
                Divider()
                     // Separator between sections

                Text("遊戲玩法")
                    .font(.title)
                    .bold()

                Text("""
                1. 只要相同顏色的堆疊被放在旁邊，就會疊加到新來的堆疊上。
                2. 一個堆疊高度超過10就會消失並加分。
                """)
                    .font(.body)
                    .padding(.bottom)
                HStack{
                    Image("before")
                        .resizable()
                        .scaledToFit()
                    Image("after")
                        .resizable()
                        .scaledToFit()
                }
                Divider()
                Text("遊戲規則")
                    .font(.title)
                    .bold()

                Text("""
                - 達到指定分數即獲勝👑。
                - 如果還沒到達指定分數時，格子全滿即失敗🌚。
                """)
                    .font(.body)
                    .padding(.bottom)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(15)
            //.shadow(radius: 10)
            .padding()
        }
        //.background(Color.blue.ignoresSafeArea()) // Background color for the entire view
    }
}


#Preview {
    ContentView()
}
