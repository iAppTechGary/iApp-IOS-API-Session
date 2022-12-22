//
//  AIArtGeneratorViewModel.swift
//  AppName
//
//  Created by iApp on 08/11/22.
//

import Foundation
import UIKit

protocol AIArtGeneratorDelegate: AnyObject{
    func didDoneText2ImageResult(_ model: Text2ImageResultDataModel?,_ message:String?)
    func didGetResultStabilityMemes(with url: String)
}

class AIArtGeneratorViewModel:NSObject {
    
    static let totalNumberOfCharactersAllowedInPrompt: Int = 500

    var text2ImageAPITimer: Timer?

    weak var delegate: AIArtGeneratorDelegate?
    
    public var currentSelectedStyle: String = ""
    public var currentAIStyle: AIStyle = .none
    public var currentSelectedMostPopularPrompt: AIArtDataModel.MostPopularPrompt?
    public var currentListPreview: ListPreview = .grid
    
    public var isShowAdvancedOption: Bool = false
    public var promtText: String = ""
    
    
    private var text2ImageTaskId: Int = 0
    
    lazy private var promptIdeasForAIArt = AIArtDataModel.PromptIdeasForAIArt.allCases.shuffled()
    
    
    private var postPopularPromptArr = AIArtDataModel.MostPopularPrompt.allCases.shuffled()
    
    public var stabilityEngine: AIArtDataModel.AIStabileEngine = .diffusion_v1
    
    public var inputImage: UIImage?
    
    var aiStyleArr: [AIStyle]{
        get{
            var array = AIStyle.allCases
            if !isShowAdvancedOption{
                array.remove(at: 0)
            }
            return array
        }
    }
    
    override init() {
        super.init()
    }
 }

extension AIArtGeneratorViewModel{
    
   
    var totalCreditScore: String{
        return String(Helper.sharedInstance.pendingCreditScore)
    }
    
    var isDailyCreditLimitClaimed: Bool{
        Helper.bool(forKey: kUserDefault.isDailyCreditLimitClamed)
    }
    
    func addDailyLimitCredit(){
        if let creditScore = Helper.value(forKey: kUserDefault.totalCreditAvailable) as? Int{
           let dailyNewLimit = creditScore + 5
            Helper.setValue(dailyNewLimit, forKey: kUserDefault.totalCreditAvailable)
            Helper.setBool(true, forKey: kUserDefault.isDailyCreditLimitClamed)
        }
    }
    
}

extension AIArtGeneratorViewModel {
    
    var numberOfMostPopularPrompt: Int{
        postPopularPromptArr.count
    }
    
    func mostPopularPrompt(index: Int) -> AIArtDataModel.MostPopularPrompt{
        return postPopularPromptArr[index]
    }
    
    

    
    var currentPrompt: String{
        if self.isShowAdvancedOption{
            let style = self.currentAIStyle.styleDetail().prompt.trim()
            let searchedText = self.promtText.trim() + " " + style
            return searchedText
        }else{
            let searchedText = self.promtText.trim()
            return searchedText
        }
    }
    
    var numberOfStyles: Int{
        return aiStyleArr.count
    }
    
    func styleAtIndex(index: Int) -> AIStyle{
        return aiStyleArr[index]
    }
    
    func didSelectStyleAtIndex(index: Int){
        currentAIStyle = aiStyleArr[index]
    }
    
    func didSelectStyle(style: AIStyle) -> Int?{
        if let index = aiStyleArr.firstIndex(where: {$0 == style}){
            currentAIStyle = aiStyleArr[index]
            return index
        }
        return nil
    }
    
    
    func isStyleSelected(atIndex index: Int) -> Bool{
        return currentAIStyle == aiStyleArr[index]
    }
    
    var numberOfIdeas: Int {
        return self.promptIdeasForAIArt.count
    }
    
    func ideasAtIndex(index: Int) -> AIArtDataModel.PromptIdeasForAIArt {
        return self.promptIdeasForAIArt[index]
    }
    
    func isOriginalPrompt(currentText: String) -> Bool{
        let curretStylePrompt = self.currentAIStyle.styleDetail().prompt
        
        if currentText == curretStylePrompt{
            return true
        }
        return false
    }
    
    func setPromptTextUptoLimit() -> String{
        let prompTextView = self.promtText //self.prompTextView.text
        let selecteStyle = self.currentAIStyle.styleDetail().prompt
        let allText = prompTextView + selecteStyle
        
        if allText.count > Self.totalNumberOfCharactersAllowedInPrompt{
            let trimmedText =  allText.truncate(to: Self.totalNumberOfCharactersAllowedInPrompt+1,ellipsis: false)
            return  trimmedText
        }
        return allText
    }
    
    
    func setMostPopularPromptWithLimit(index: Int) -> String{
        let prompt = postPopularPromptArr[index]
        currentSelectedMostPopularPrompt = prompt
        let selecteStyle =  prompt.styleDetail().prompt
        let allText = selecteStyle
        
        if allText.count > Self.totalNumberOfCharactersAllowedInPrompt {
            let trimmedText =  allText.truncate(to: Self.totalNumberOfCharactersAllowedInPrompt+1,ellipsis: false)
            return  trimmedText
        }
        return allText
    }
    
    
    
    func isExceedTheLimit(with promptInTextView: String) -> Bool {
        return promptInTextView.count <= Self.totalNumberOfCharactersAllowedInPrompt
    }
    
    var countOfTotalNumberOfCharacters: String {
        return "\(self.promtText.count)/\(Self.totalNumberOfCharactersAllowedInPrompt)"
    }
    
}


extension AIArtGeneratorViewModel {
    
    
    func createTextToImageAICutPro() {
        if !APIManager.shared().isInternetAvailable{
            self.didUpdateText2ImageResult(nil, "Internet is not available, Please try again.")
            return
        }
        let style = self.currentAIStyle.styleDetail().prompt.trim()
        let searchedText = self.promtText.trim() + " " + style
      
        let parameterType = ParameterType.text2imageAsync(prompt: searchedText, style: nil, imageUrl: nil)

        let stability = EndpointItem.stability(searchedText) //EndpointItem.text2imageAsync, parameterType.params
        
        _ = APIManager.shared().call(type: stability , params: nil) {[weak self] (model: CutOutModel?) in
            debugPrint(model ?? "")
            if let sucess = model?.success{
                if sucess, let url = model?.url{
                    self?.delegate?.didGetResultStabilityMemes(with: url)
                }else{
                    self?.didUpdateText2ImageResult(nil, "Something went wrong, please try again.")
                }
            }else{
                self?.didUpdateText2ImageResult(nil, "Something went wrong, please try again.")
            }
        } _: { [weak self] (error) in
            debugPrint(error ?? "")
            self?.didUpdateText2ImageResult(nil, error.debugDescription)
        }
    }
    
    func scheduledTimerWithTimeInterval(){
       // Scheduling timer to Call the function "updateCounting" with the interval of 1 seconds
       text2ImageAPITimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.updateCounting), userInfo: nil, repeats: true)
   }

   @objc func updateCounting(){
       self.createTextToImageResult(with: self.text2ImageTaskId)
   }

  
    private func didUpdateText2ImageResult(_ model: Text2ImageResultDataModel?,_ message:String?){
        self.invalidateText2ImageTimer()
        self.delegate?.didDoneText2ImageResult(model, message)
    }
    
    private func invalidateText2ImageTimer(){
        text2ImageAPITimer?.invalidate()
        text2ImageAPITimer = nil
    }
}
